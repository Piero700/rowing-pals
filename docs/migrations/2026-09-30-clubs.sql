-- Clubs (phase G, decisions 7 and 25). Run once in the Supabase SQL editor, staging first,
-- then docs/migrations/2026-09-30-club-directory.sql. Safe to run again.
--
-- Membership stays one club per rower (profiles.club_id) with a role beside it. Joining,
-- leaving, requests, invites, roles and ownership change ONLY through the functions below:
-- a trigger rejects any other change to profiles.club_id / club_role, so nobody can walk
-- into an approval-only or invitation-only club by writing their own profile.

do $$ begin
  create type club_join_policy as enum ('open', 'approval', 'invite');
exception when duplicate_object then null; end $$;
do $$ begin
  create type club_role as enum ('member', 'admin', 'co_owner', 'owner');
exception when duplicate_object then null; end $$;

alter table clubs add column if not exists description text;
alter table clubs add column if not exists join_policy club_join_policy not null default 'open';
alter table clubs add column if not exists focus text not null default 'All rowing';
-- No created_by column: a second clubs↔profiles link would make every existing
-- `clubs(name)` lookup from profiles ambiguous. The owner is whoever has club_role 'owner'.
alter table clubs drop constraint if exists clubs_focus_check;
alter table clubs add constraint clubs_focus_check
  check (focus in ('All rowing', 'Indoor rowing', 'On-water rowing', 'University crew'));
alter table clubs drop constraint if exists clubs_text_lengths;
alter table clubs add constraint clubs_text_lengths
  check (char_length(name) between 1 and 60
         and (description is null or char_length(description) <= 400)
         and (location is null or char_length(location) <= 80));
create unique index if not exists clubs_name_unique on clubs (lower(name));

alter table profiles add column if not exists club_role club_role not null default 'member';

-- One pending request per rower: asking another club replaces it.
create table if not exists club_join_requests (
  user_id    uuid primary key references profiles on delete cascade,
  club_id    uuid not null references clubs on delete cascade,
  created_at timestamptz not null default now()
);
-- Its own id, and uniqueness by index rather than a (club_id, user_id) key: a key made of
-- both links would make PostgREST read this as a profiles↔clubs many-to-many route, and every
-- `clubs(name)` lookup from profiles would become ambiguous.
create table if not exists club_invites (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references clubs on delete cascade,
  user_id    uuid not null references profiles on delete cascade,
  invited_by uuid references profiles on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists club_invites_club_user on club_invites (club_id, user_id);
-- Kept out of `clubs`, which every rower can read.
create table if not exists club_invite_codes (
  club_id    uuid primary key references clubs on delete cascade,
  code       text not null unique,
  created_at timestamptz not null default now()
);
create index if not exists club_join_requests_club_idx on club_join_requests (club_id);
create index if not exists club_invites_user_idx on club_invites (user_id);

create or replace function club_rank(r club_role)
returns int
language sql immutable as $$
  select case r when 'member' then 0 when 'admin' then 1 when 'co_owner' then 2 else 3 end;
$$;

-- Whether the caller manages `p_club` at `p_min` or above.
create or replace function is_club_manager(p_club uuid, p_min club_role)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p
    where p.id = auth.uid() and p.club_id = p_club and club_rank(p.club_role) >= club_rank(p_min)
  );
$$;

alter table club_join_requests enable row level security;
alter table club_invites enable row level security;
alter table club_invite_codes enable row level security;
drop policy if exists read_own_or_managed on club_join_requests;
create policy read_own_or_managed on club_join_requests for select to authenticated
  using (user_id = auth.uid() or is_club_manager(club_id, 'admin'));
drop policy if exists read_own_or_managed on club_invites;
create policy read_own_or_managed on club_invites for select to authenticated
  using (user_id = auth.uid() or is_club_manager(club_id, 'admin'));
drop policy if exists read_managed on club_invite_codes;
create policy read_managed on club_invite_codes for select to authenticated
  using (is_club_manager(club_id, 'admin'));

-- The guard. The functions below switch it off for their own transaction only.
create or replace function profiles_guard_club()
returns trigger
language plpgsql as $$
begin
  if coalesce(current_setting('rp.club_change', true), '') = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.club_id is not null or new.club_role <> 'member' then
      raise exception 'Join a club from the app';
    end if;
  elsif new.club_id is distinct from old.club_id or new.club_role is distinct from old.club_role then
    raise exception 'Club membership changes go through the app';
  end if;
  return new;
end $$;
drop trigger if exists profiles_guard_club on profiles;
create trigger profiles_guard_club
  before insert or update on profiles
  for each row execute function profiles_guard_club();

-- MARK: - Joining and leaving

-- Owners must hand over or delete their club first, or it would be left without one.
create or replace function club_assert_not_owner()
returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if exists (select 1 from profiles where id = auth.uid() and club_id is not null and club_role = 'owner') then
    raise exception 'You own your club. Hand it over to another member or delete it first.';
  end if;
end $$;

create or replace function club_set_membership(p_user uuid, p_club uuid, p_role club_role)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('rp.club_change', 'on', true);
  update profiles set club_id = p_club, club_role = p_role where id = p_user;
  if p_club is not null then
    delete from club_join_requests where user_id = p_user;
    delete from club_invites where user_id = p_user and club_id = p_club;
  end if;
end $$;

-- 'joined' (open club, or you were invited), 'requested' (approval club), 'invite_only'.
create or replace function join_club(p_club uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_policy club_join_policy;
  v_current uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select join_policy into v_policy from clubs where id = p_club;
  if not found then raise exception 'That club no longer exists.'; end if;
  select club_id into v_current from profiles where id = auth.uid();
  if v_current = p_club then return 'joined'; end if;
  perform club_assert_not_owner();
  if v_policy = 'open' or exists (select 1 from club_invites where club_id = p_club and user_id = auth.uid()) then
    perform club_set_membership(auth.uid(), p_club, 'member');
    return 'joined';
  elsif v_policy = 'approval' then
    insert into club_join_requests (user_id, club_id) values (auth.uid(), p_club)
    on conflict (user_id) do update set club_id = excluded.club_id, created_at = now();
    return 'requested';
  end if;
  return 'invite_only';
end $$;

create or replace function join_club_with_code(p_code text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select club_id into v_club from club_invite_codes where code = upper(trim(p_code));
  if v_club is null then raise exception 'That invite code isn''t right. Check it with the club.'; end if;
  if exists (select 1 from profiles where id = auth.uid() and club_id = v_club) then return v_club; end if;
  perform club_assert_not_owner();
  perform club_set_membership(auth.uid(), v_club, 'member');
  return v_club;
end $$;

create or replace function leave_club()
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform club_assert_not_owner();
  perform club_set_membership(auth.uid(), null, 'member');
end $$;

create or replace function cancel_join_request()
returns void
language sql security definer set search_path = public as $$
  delete from club_join_requests where user_id = auth.uid();
$$;

create or replace function respond_club_invite(p_club uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from club_invites where club_id = p_club and user_id = auth.uid()) then
    raise exception 'That invitation has been withdrawn.';
  end if;
  if p_accept then
    perform club_assert_not_owner();
    perform club_set_membership(auth.uid(), p_club, 'member');
  else
    delete from club_invites where club_id = p_club and user_id = auth.uid();
  end if;
end $$;

-- MARK: - Creating and editing

create or replace function create_club(p_name text, p_description text, p_location text, p_policy club_join_policy, p_focus text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  perform club_assert_not_owner();
  begin
    insert into clubs (name, description, location, join_policy, focus)
    values (trim(p_name), nullif(trim(p_description), ''), nullif(trim(p_location), ''), p_policy, p_focus)
    returning id into v_club;
  exception when unique_violation then
    raise exception 'A club with that name already exists. Find it and ask to join.';
  end;
  perform club_set_membership(auth.uid(), v_club, 'owner');
  return v_club;
end $$;

create or replace function update_club(p_name text, p_description text, p_location text, p_policy club_join_policy, p_focus text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'co_owner') then
    raise exception 'Only the owner and co-owners can edit the club.';
  end if;
  begin
    update clubs
    set name = trim(p_name), description = nullif(trim(p_description), ''),
        location = nullif(trim(p_location), ''), join_policy = p_policy, focus = p_focus
    where id = v_club;
  exception when unique_violation then
    raise exception 'Another club already has that name.';
  end;
end $$;

-- MARK: - Managing members (admins and up)

create or replace function respond_join_request(p_user uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from club_join_requests where user_id = p_user;
  if v_club is null then raise exception 'That request has been withdrawn.'; end if;
  if not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can answer requests.';
  end if;
  if p_accept then
    if exists (select 1 from profiles where id = p_user and club_id is not null and club_role = 'owner') then
      raise exception 'They own another club, so they can''t join until they hand it over.';
    end if;
    perform club_set_membership(p_user, v_club, 'member');
  else
    delete from club_join_requests where user_id = p_user;
  end if;
end $$;

create or replace function invite_rower(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can invite rowers.';
  end if;
  if exists (select 1 from profiles where id = p_user and club_id = v_club) then
    raise exception 'They''re already in the club.';
  end if;
  insert into club_invites (club_id, user_id, invited_by) values (v_club, p_user, auth.uid())
  on conflict do nothing;
end $$;

create or replace function withdraw_club_invite(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can withdraw invitations.';
  end if;
  delete from club_invites where club_id = v_club and user_id = p_user;
end $$;

-- The club's invite code, made on first request. Admins and up.
create or replace function club_invite_code(p_new boolean default false)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_code text;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can share the invite code.';
  end if;
  select code into v_code from club_invite_codes where club_id = v_club;
  if v_code is null or p_new then
    loop
      v_code := upper(substr(md5(gen_random_uuid()::text), 1, 8));
      begin
        insert into club_invite_codes (club_id, code) values (v_club, v_code)
        on conflict (club_id) do update set code = excluded.code, created_at = now();
        exit;
      exception when unique_violation then
        -- Another club already has this code; try another.
      end;
    end loop;
  end if;
  return v_code;
end $$;

-- Roles: co-owners and the owner change them; only the owner makes or unmakes co-owners.
-- Nobody changes the role of someone at or above their own.
create or replace function set_club_role(p_user uuid, p_role club_role)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_mine club_role;
  v_theirs club_role;
begin
  if p_role = 'owner' then raise exception 'Use Hand over ownership instead.'; end if;
  select club_id, club_role into v_club, v_mine from profiles where id = auth.uid();
  select club_role into v_theirs from profiles where id = p_user and club_id = v_club;
  if v_club is null or v_theirs is null or p_user = auth.uid() then
    raise exception 'They''re not in your club.';
  end if;
  if club_rank(v_mine) < club_rank('co_owner')
     or club_rank(v_theirs) >= club_rank(v_mine)
     or (p_role = 'co_owner' and v_mine <> 'owner') then
    raise exception 'You can''t change that role.';
  end if;
  perform club_set_membership(p_user, v_club, p_role);
end $$;

-- Admins remove members; co-owners also admins; the owner anyone.
create or replace function remove_club_member(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_mine club_role;
  v_theirs club_role;
begin
  select club_id, club_role into v_club, v_mine from profiles where id = auth.uid();
  select club_role into v_theirs from profiles where id = p_user and club_id = v_club;
  if v_club is null or v_theirs is null or p_user = auth.uid() then
    raise exception 'They''re not in your club.';
  end if;
  if club_rank(v_mine) < club_rank('admin') or club_rank(v_theirs) >= club_rank(v_mine) then
    raise exception 'You can''t remove them.';
  end if;
  perform club_set_membership(p_user, null, 'member');
end $$;

-- MARK: - Ownership

-- The new owner takes over; the old owner stays on as a co-owner.
create or replace function transfer_club_ownership(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid() and club_role = 'owner';
  if v_club is null then raise exception 'Only the owner can hand over the club.'; end if;
  if not exists (select 1 from profiles where id = p_user and club_id = v_club) or p_user = auth.uid() then
    raise exception 'They''re not in your club.';
  end if;
  perform club_set_membership(p_user, v_club, 'owner');
  perform club_set_membership(auth.uid(), v_club, 'co_owner');
end $$;

-- Everyone in it is left without a club; their sessions, metres and PBs stay theirs.
create or replace function delete_club()
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid() and club_role = 'owner';
  if v_club is null then raise exception 'Only the owner can delete the club.'; end if;
  perform set_config('rp.club_change', 'on', true);
  update profiles set club_id = null, club_role = 'member' where club_id = v_club;
  delete from clubs where id = v_club;
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'join_club(uuid)', 'join_club_with_code(text)', 'leave_club()', 'cancel_join_request()',
    'respond_club_invite(uuid, boolean)',
    'create_club(text, text, text, club_join_policy, text)',
    'update_club(text, text, text, club_join_policy, text)',
    'respond_join_request(uuid, boolean)', 'invite_rower(uuid)', 'withdraw_club_invite(uuid)',
    'club_invite_code(boolean)', 'set_club_role(uuid, club_role)', 'remove_club_member(uuid)',
    'transfer_club_ownership(uuid)', 'delete_club()'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array['club_assert_not_owner()', 'club_set_membership(uuid, uuid, club_role)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $$;
