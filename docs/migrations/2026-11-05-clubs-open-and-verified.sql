-- Clubs anyone can start, unique names, renaming, and verified clubs (decision 98).
-- Run once in the Supabase SQL editor, Staging first. Safe to run again.
--
-- Run docs/migrations/2026-11-05-delete-all-clubs.sql FIRST if you're clearing the clubs out:
-- the stricter name index below can't be built while two clubs share a name that differs only by
-- spacing ("Tyne  RC" and "Tyne RC").
--
-- What it does:
--   * Club names are unique ignoring capitals and extra spaces ("Tyne RC", "tyne rc" and
--     " Tyne  RC " are one name), enforced by a unique index, and stored tidied.
--   * create_club / update_club tidy the name and say clearly when it's taken.
--   * rename_club: the owner (and co-owners, who can already edit the club) change just the name.
--   * club_name_is_free: the app checks a name as it's typed.
--   * Verified clubs: clubs.is_verified, set only by you in the SQL editor
--     (approve_club_verification). An owner applies from the app (apply_for_club_verification);
--     the application waits in club_verification_requests.

-- MARK: - Names

-- The one form two names are compared in: lower case, trimmed, runs of spaces made one.
create or replace function club_name_key(p_name text)
returns text
language sql immutable as $$
  select lower(regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g'));
$$;

drop index if exists clubs_name_unique;
create unique index clubs_name_unique on clubs (club_name_key(name));

-- Names are stored tidied (trimmed, single spaces). NOT VALID: checked for every new or changed
-- name, without failing on an older untidy one.
alter table clubs drop constraint if exists clubs_name_tidy;
alter table clubs add constraint clubs_name_tidy
  check (name = regexp_replace(btrim(name), '\s+', ' ', 'g')) not valid;

-- True when no other club has this name (ignoring capitals and spaces). `p_except` is the
-- caller's own club when renaming, so keeping its own name, or changing its capitals, is fine.
create or replace function club_name_is_free(p_name text, p_except uuid default null)
returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from clubs
    where club_name_key(name) = club_name_key(p_name)
      and (p_except is null or id <> p_except)
  );
$$;

-- MARK: - Verified clubs

alter table clubs add column if not exists is_verified boolean not null default false;
alter table clubs add column if not exists verified_at timestamptz;

-- One application per club: applying again after a decline replaces it.
create table if not exists club_verification_requests (
  club_id      uuid primary key references clubs on delete cascade,
  requested_by uuid references profiles on delete set null,
  message      text check (message is null or char_length(message) <= 500),
  status       text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  created_at   timestamptz not null default now(),
  decided_at   timestamptz
);
alter table club_verification_requests enable row level security;
-- The club's owner and co-owners can see where its application stands. Nobody writes the
-- table directly: applying goes through apply_for_club_verification, deciding through you.
drop policy if exists read_own_club on club_verification_requests;
create policy read_own_club on club_verification_requests
  for select to authenticated using (is_club_manager(club_id, 'co_owner'));

-- MARK: - Creating, editing and renaming

create or replace function create_club(p_name text, p_description text, p_location text, p_policy club_join_policy, p_focus text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_name text := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if v_name = '' then raise exception 'Give your club a name.'; end if;
  perform club_assert_not_owner();
  if not club_name_is_free(v_name) then
    raise exception 'There''s already a club called %. Club names have to be different (capitals don''t count), so choose another name.', v_name;
  end if;
  begin
    insert into clubs (name, description, location, join_policy, focus)
    values (v_name, nullif(trim(p_description), ''), nullif(trim(p_location), ''), p_policy, p_focus)
    returning id into v_club;
  exception when unique_violation then
    raise exception 'There''s already a club called %. Club names have to be different (capitals don''t count), so choose another name.', v_name;
  end;
  perform club_set_membership(auth.uid(), v_club, 'owner');
  return v_club;
end $$;

create or replace function update_club(p_name text, p_description text, p_location text, p_policy club_join_policy, p_focus text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_name text := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'co_owner') then
    raise exception 'Only the owner and co-owners can edit the club.';
  end if;
  if v_name = '' then raise exception 'Give your club a name.'; end if;
  if not club_name_is_free(v_name, v_club) then
    raise exception 'There''s already a club called %. Choose another name.', v_name;
  end if;
  begin
    update clubs
    set name = v_name, description = nullif(trim(p_description), ''),
        location = nullif(trim(p_location), ''), join_policy = p_policy, focus = p_focus
    where id = v_club;
  exception when unique_violation then
    raise exception 'There''s already a club called %. Choose another name.', v_name;
  end;
end $$;

-- Settings → Your club → Club name. Same rule as editing the club.
create or replace function rename_club(p_name text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_name text := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'co_owner') then
    raise exception 'Only the owner and co-owners can rename the club.';
  end if;
  if v_name = '' then raise exception 'Give your club a name.'; end if;
  if char_length(v_name) > 60 then raise exception 'Club names can be up to 60 characters.'; end if;
  if not club_name_is_free(v_name, v_club) then
    raise exception 'There''s already a club called %. Choose another name.', v_name;
  end if;
  begin
    update clubs set name = v_name where id = v_club;
  exception when unique_violation then
    raise exception 'There''s already a club called %. Choose another name.', v_name;
  end;
end $$;

-- MARK: - Applying for verification

-- The owner asks for the verified tag. Returns 'pending'.
create or replace function apply_for_club_verification(p_message text)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_status text;
begin
  select club_id into v_club from profiles where id = auth.uid() and club_role = 'owner';
  if v_club is null then raise exception 'Only the club''s owner can apply for verification.'; end if;
  if exists (select 1 from clubs where id = v_club and is_verified) then
    raise exception 'Your club is already verified.';
  end if;
  select status into v_status from club_verification_requests where club_id = v_club;
  if v_status = 'pending' then
    raise exception 'Your application is already waiting to be looked at.';
  end if;
  insert into club_verification_requests (club_id, requested_by, message, status, created_at, decided_at)
  values (v_club, auth.uid(), nullif(left(btrim(coalesce(p_message, '')), 500), ''), 'pending', now(), null)
  on conflict (club_id) do update
    set requested_by = excluded.requested_by, message = excluded.message,
        status = 'pending', created_at = now(), decided_at = null;
  return 'pending';
end $$;

-- Where the caller's club stands: 'verified', 'pending', 'declined' or 'none'.
create or replace function club_verification_status()
returns text
language sql stable security definer set search_path = public as $$
  select case
    when c.is_verified then 'verified'
    else coalesce((select r.status from club_verification_requests r where r.club_id = c.id), 'none')
  end
  from profiles p join clubs c on c.id = p.club_id
  where p.id = auth.uid();
$$;

-- MARK: - Deciding (you, in the SQL editor only)

-- select approve_club_verification('<club id>');
create or replace function approve_club_verification(p_club uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update clubs set is_verified = true, verified_at = now() where id = p_club;
  if not found then raise exception 'No club has that id.'; end if;
  insert into club_verification_requests (club_id, status, decided_at)
  values (p_club, 'approved', now())
  on conflict (club_id) do update set status = 'approved', decided_at = now();
end $$;

-- select decline_club_verification('<club id>');  The owner can apply again.
create or replace function decline_club_verification(p_club uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update club_verification_requests set status = 'declined', decided_at = now() where club_id = p_club;
  if not found then raise exception 'That club hasn''t applied.'; end if;
end $$;

-- select remove_club_verification('<club id>');  Takes the tag away again.
create or replace function remove_club_verification(p_club uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update clubs set is_verified = false, verified_at = null where id = p_club;
  if not found then raise exception 'No club has that id.'; end if;
end $$;

-- MARK: - Who can call what

do $$
declare
  f text;
begin
  foreach f in array array[
    'create_club(text, text, text, club_join_policy, text)',
    'update_club(text, text, text, club_join_policy, text)',
    'rename_club(text)', 'club_name_is_free(text, uuid)',
    'apply_for_club_verification(text)', 'club_verification_status()'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  -- Deciding is yours alone: nobody signed in to the app can call these.
  foreach f in array array[
    'approve_club_verification(uuid)', 'decline_club_verification(uuid)', 'remove_club_verification(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $$;

-- Ask PostgREST to pick up the new column and functions straight away.
notify pgrst, 'reload schema';
