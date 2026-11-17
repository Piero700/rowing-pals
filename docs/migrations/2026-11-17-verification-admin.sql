-- Club verification decided in the app (decision 108, user 2026-11-17). Run once in the Supabase
-- SQL editor, staging first. Safe to run again.
--
-- Until now verification requests (decision 98) were decided only here, with
-- approve_club_verification('<club id>'). This adds app admins — people allowed to decide them in
-- the app, under Settings → Club verifications — and the functions that screen uses. Admins are
-- listed in app_admins, which nobody can read or change from the app: you add and remove them here.
-- The SQL-editor functions keep working.
--
-- After running it, make yourself an admin (one line, below the commit).

begin;

-- MARK: - 1. Who the app admins are

create table if not exists app_admins (
  user_id  uuid primary key references profiles on delete cascade,
  added_at timestamptz not null default now()
);
-- No policies: the app can't read or write it; only the functions below look at it.
alter table app_admins enable row level security;

create or replace function is_app_admin()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from app_admins where user_id = auth.uid());
$$;

-- MARK: - 2. The list an admin sees

-- Every application (newest first, waiting ones before decided ones in the app), and every
-- verified club, with who asked and what they wrote.
create or replace function admin_club_verifications()
returns table (
  club_id uuid, club_name text, location text, member_count int,
  requested_by_name text, requested_by_username text, message text,
  status text, is_verified boolean, created_at timestamptz, decided_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_app_admin() then
    raise exception 'Only the app''s admins can see club verifications.';
  end if;
  return query
    select c.id, c.name, c.location,
           (select count(*)::int from profiles m where m.club_id = c.id),
           p.display_name, p.username, r.message,
           case when c.is_verified then 'approved' else coalesce(r.status, 'none') end,
           c.is_verified, coalesce(r.created_at, c.verified_at, c.created_at), coalesce(r.decided_at, c.verified_at)
    from clubs c
    left join club_verification_requests r on r.club_id = c.id
    left join profiles p on p.id = r.requested_by
    where r.club_id is not null or c.is_verified
    order by coalesce(r.created_at, c.verified_at, c.created_at) desc;
end $$;

-- MARK: - 3. Deciding

-- 'approve' gives the club the verified tag; 'decline' turns the application down (the owner can
-- apply again); 'remove' takes the tag away again.
create or replace function admin_decide_club_verification(p_club uuid, p_decision text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_app_admin() then
    raise exception 'Only the app''s admins can decide club verifications.';
  end if;
  case p_decision
    when 'approve' then perform approve_club_verification(p_club);
    when 'decline' then perform decline_club_verification(p_club);
    when 'remove'  then perform remove_club_verification(p_club);
    else raise exception 'Unknown decision: %', p_decision;
  end case;
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'is_app_admin()', 'admin_club_verifications()', 'admin_decide_club_verification(uuid, text)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

commit;

-- The API sees the new functions straight away.
notify pgrst, 'reload schema';

-- MARK: - Make yourself an admin (run once, with your own username)
--
-- insert into app_admins (user_id)
-- select id from profiles where username = 'piero'
-- on conflict do nothing;
--
-- To remove an admin:  delete from app_admins where user_id = (select id from profiles where username = '...');
