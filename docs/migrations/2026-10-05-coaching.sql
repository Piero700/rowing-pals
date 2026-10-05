-- Coaching (decisions 34, 35, 39, 40, 45–47). Run once in the Supabase SQL editor, staging first.
-- Safe to run again. RUN THIS BEFORE INSTALLING A BUILD THAT INCLUDES IT.
--
-- One file for the whole coaching section (decision 39): Phase 1 uses the coach flag, the
-- account type, squads and the read rules; the workout and attendance tables are created now and
-- their write functions arrive with Phases 2 and 3 (this file is updated then; run it again).
--
--   1. Coach flag and account type on profiles
--   2. Who coaches whom: helper functions
--   3. Coaches read their club's rowers — read-only (decision 40)
--   4. Squads
--   5. Set workouts (tables only; Phase 2)
--   6. Practices and attendance (tables only; Phase 3)
--
-- No second foreign key between clubs and profiles (it would make `clubs(name)` embeds
-- ambiguous): coaching hangs off profiles.club_id, like club roles.

begin;

-- MARK: - 1. Coach flag and account type

-- A coach is a separate flag beside the club role (decision 39). It belongs to the rower's one
-- club and is cleared whenever their club changes.
alter table profiles add column if not exists is_coach boolean not null default false;
-- "I row" (true) or "Coach only" (false). Coach-only accounts never appear on a leaderboard, a
-- test board, a club ranking or in Crewmates, have no Log button and no gender or level.
alter table profiles add column if not exists is_rower boolean not null default true;
-- When they joined their current club, for "Senior · joined Sep 2025" in a member's sheet.
-- Empty for anyone who joined before this migration.
alter table profiles add column if not exists club_joined_at timestamptz;

-- The guard from 2026-09-30-clubs.sql, now also protecting the coach flag and the join date:
-- only the functions below change them, inside their own transaction.
create or replace function profiles_guard_club()
returns trigger
language plpgsql as $$
begin
  if coalesce(current_setting('rp.club_change', true), '') = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.club_id is not null or new.club_role <> 'member' or new.is_coach or new.club_joined_at is not null then
      raise exception 'Join a club from the app';
    end if;
  elsif new.club_id is distinct from old.club_id
     or new.club_role is distinct from old.club_role
     or new.is_coach is distinct from old.is_coach
     or new.club_joined_at is distinct from old.club_joined_at then
    raise exception 'Club membership changes go through the app';
  end if;
  return new;
end $$;

-- Squads are created below; club_set_membership refers to them.
create table if not exists squads (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references clubs on delete cascade,
  name       text not null check (char_length(btrim(name)) between 1 and 40),
  created_at timestamptz not null default now()
);
create unique index if not exists squads_club_name on squads (club_id, lower(btrim(name)));

create table if not exists squad_members (
  squad_id uuid not null references squads on delete cascade,
  user_id  uuid not null references profiles on delete cascade,
  primary key (squad_id, user_id)
);
create index if not exists squad_members_user on squad_members (user_id);

-- Every membership change goes through here (joining, leaving, roles, removal, hand-over).
-- Moving to a different club, or none, ends coaching and squad places in the old one.
create or replace function club_set_membership(p_user uuid, p_club uuid, p_role club_role)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('rp.club_change', 'on', true);
  update profiles
     set club_id = p_club,
         club_role = p_role,
         is_coach = is_coach and club_id is not distinct from p_club,
         club_joined_at = case
           when club_id is not distinct from p_club then club_joined_at
           when p_club is null then null
           else now()
         end
   where id = p_user;
  delete from squad_members sm
   using squads s
   where sm.squad_id = s.id and sm.user_id = p_user and s.club_id is distinct from p_club;
  if p_club is not null then
    delete from club_join_requests where user_id = p_user;
    delete from club_invites where user_id = p_user and club_id = p_club;
  end if;
end $$;

create or replace function delete_club()
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid() and club_role = 'owner';
  if v_club is null then raise exception 'Only the owner can delete the club.'; end if;
  perform set_config('rp.club_change', 'on', true);
  update profiles set club_id = null, club_role = 'member', is_coach = false, club_joined_at = null
   where club_id = v_club;
  delete from clubs where id = v_club;
end $$;

-- Make someone a coach, or stop: the owner and co-owners, for a member of their own club
-- (themselves included — an owner can coach).
create or replace function set_club_coach(p_user uuid, p_on boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'co_owner') then
    raise exception 'Only the owner and co-owners can make someone a coach.';
  end if;
  if not exists (select 1 from profiles where id = p_user and club_id = v_club) then
    raise exception 'They''re not in your club.';
  end if;
  perform set_config('rp.club_change', 'on', true);
  update profiles set is_coach = p_on where id = p_user;
end $$;

-- Which club an invite code opens, without joining it, so the app can say "<Club> has coaches"
-- before someone joins with a code (decision 34). Says no more than joining with it would.
create or replace function club_for_invite_code(p_code text)
returns uuid
language plpgsql stable security definer set search_path = public as $$
declare
  v_club uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select club_id into v_club from club_invite_codes where code = upper(trim(p_code));
  if v_club is null then raise exception 'That invite code isn''t right. Check it with the club.'; end if;
  return v_club;
end $$;

-- MARK: - 2. Who coaches whom

-- Whether the caller coaches `p_club`.
create or replace function is_club_coach(p_club uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p where p.id = auth.uid() and p.club_id = p_club and p.is_coach
  );
$$;

-- Whether the caller coaches `p_user` (they're in the club the caller coaches).
create or replace function coaches_rower(p_user uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from profiles me
    join profiles them on them.club_id = me.club_id
    where me.id = auth.uid() and me.is_coach and me.club_id is not null and them.id = p_user
  );
$$;

-- Coaches, the owner and co-owners look after squads (decision 39).
create or replace function can_manage_squads(p_club uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select is_club_coach(p_club) or is_club_manager(p_club, 'co_owner');
$$;

-- MARK: - 3. Coaches read their club's rowers (read-only, decision 40)

-- A rower's own data (test results, daily totals, profile pictures): the private-account rule,
-- plus their club's coaches.
create or replace function can_view_user(target uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select target = auth.uid()
    or not coalesce((select p.is_private from profiles p where p.id = target), false)
    or exists (
      select 1 from follows f
      where f.follower_id = auth.uid()
        and f.followee_id = target
        and f.status = 'accepted'
    )
    or coaches_rower(target);
$$;

-- Reading a post and everything on it: whoever may see it under decision 33, plus the
-- author's club's coaches. Writing (comments, reactions) still uses can_view_session() alone,
-- so a coach's extra access stays read-only.
create or replace function can_read_session(sid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select can_view_session(sid)
    or coalesce((select coaches_rower(s.user_id) from sessions s where s.id = sid), false);
$$;

-- Of these posts, the ones the caller may comment on and react to: those decision 33 lets them
-- see, not just their coaching (decision 40). The app greys out the rest, read-only.
create or replace function sessions_i_can_interact_with(p_ids uuid[])
returns setof uuid
language sql stable security definer set search_path = public as $$
  select id from unnest(coalesce(p_ids, '{}')) as id where can_view_session(id);
$$;

drop policy if exists read_visible on sessions;
create policy read_visible on sessions for select to authenticated using (can_read_session(id));
drop policy if exists read_visible on segments;
create policy read_visible on segments for select to authenticated using (can_read_session(session_id));
drop policy if exists read_visible on session_photos;
create policy read_visible on session_photos for select to authenticated using (can_read_session(session_id));
drop policy if exists read_visible on reactions;
create policy read_visible on reactions for select to authenticated using (can_read_session(session_id));
drop policy if exists read_visible on comments;
create policy read_visible on comments for select to authenticated using (can_read_session(session_id));

drop policy if exists read_visible_photos on storage.objects;
create policy read_visible_photos on storage.objects
  for select to authenticated
  using (
    bucket_id in ('monitors', 'selfies')
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or can_read_session(photo_session_id(name))
    )
  );

-- Date of birth and bodyweight: the rower, and now their club's coaches (decision 35). Read
-- only — own_row still decides who may change them.
drop policy if exists coach_read on athlete_private;
create policy coach_read on athlete_private for select to authenticated
  using (coaches_rower(user_id));

-- MARK: - 4. Squads

alter table squads enable row level security;
alter table squad_members enable row level security;

-- Everyone in the club sees its squads (a workout says which squads it's for); writes go
-- through the functions below.
drop policy if exists read_own_club on squads;
create policy read_own_club on squads for select to authenticated
  using (club_id = (select p.club_id from profiles p where p.id = auth.uid()));
drop policy if exists read_own_club on squad_members;
create policy read_own_club on squad_members for select to authenticated
  using (exists (
    select 1 from squads s
    where s.id = squad_id and s.club_id = (select p.club_id from profiles p where p.id = auth.uid())
  ));

create or replace function create_squad(p_name text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not can_manage_squads(v_club) then
    raise exception 'Only coaches, the owner and co-owners can manage squads.';
  end if;
  if exists (select 1 from squads where club_id = v_club and lower(btrim(name)) = lower(btrim(p_name))) then
    raise exception 'Your club already has a squad called that.';
  end if;
  insert into squads (club_id, name) values (v_club, btrim(p_name)) returning id into v_id;
  return v_id;
end $$;

create or replace function rename_squad(p_squad uuid, p_name text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from squads where id = p_squad;
  if v_club is null then raise exception 'That squad no longer exists.'; end if;
  if not can_manage_squads(v_club) then
    raise exception 'Only coaches, the owner and co-owners can manage squads.';
  end if;
  if exists (select 1 from squads where club_id = v_club and id <> p_squad and lower(btrim(name)) = lower(btrim(p_name))) then
    raise exception 'Your club already has a squad called that.';
  end if;
  update squads set name = btrim(p_name) where id = p_squad;
end $$;

create or replace function delete_squad(p_squad uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from squads where id = p_squad;
  if v_club is null then return; end if;
  if not can_manage_squads(v_club) then
    raise exception 'Only coaches, the owner and co-owners can manage squads.';
  end if;
  delete from squads where id = p_squad;
end $$;

-- Replaces the squad's members with `p_users`; anyone not in the club is ignored. A rower can
-- be in several squads.
create or replace function set_squad_members(p_squad uuid, p_users uuid[])
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from squads where id = p_squad;
  if v_club is null then raise exception 'That squad no longer exists.'; end if;
  if not can_manage_squads(v_club) then
    raise exception 'Only coaches, the owner and co-owners can manage squads.';
  end if;
  delete from squad_members where squad_id = p_squad;
  insert into squad_members (squad_id, user_id)
    select p_squad, p.id from profiles p
    where p.id = any(coalesce(p_users, '{}')) and p.club_id = v_club
  on conflict do nothing;
end $$;

-- MARK: - 5. Set workouts (Phase 2 adds the write functions)

create table if not exists coach_workouts (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references clubs on delete cascade,
  created_by   uuid references profiles on delete set null,
  title        text not null check (char_length(btrim(title)) between 1 and 80),
  workout_date date not null,
  start_time   time,
  description  text check (description is null or char_length(description) <= 2000),
  zone         text check (zone is null or zone in ('UT2', 'UT1', 'AT', 'TR', 'AN')),
  -- A standard test ('2k') or a club test ('club:<id>') when it's a test day.
  test_key     text,
  -- [{ "kind": "distance"|"time", "value": metres or ms, "reps": n, "rest_ms": n,
  --    "rate_min": n, "rate_max": n, "split_ms": n }]
  pieces       jsonb not null default '[]'::jsonb,
  -- 'club', 'squads' or 'rowers'; the squads or rowers are in coach_workout_targets.
  audience     text not null default 'club' check (audience in ('club', 'squads', 'rowers')),
  created_at   timestamptz not null default now()
);
create index if not exists coach_workouts_club_date on coach_workouts (club_id, workout_date);

create table if not exists coach_workout_targets (
  workout_id uuid not null references coach_workouts on delete cascade,
  squad_id   uuid references squads on delete cascade,
  user_id    uuid references profiles on delete cascade,
  check ((squad_id is null) <> (user_id is null))
);
create index if not exists coach_workout_targets_workout on coach_workout_targets (workout_id);

-- A logged session can say which set workout it was (decision 39: posting while Today's
-- workout shows links it).
alter table sessions add column if not exists workout_id uuid references coach_workouts on delete set null;

-- Whether a workout is set for the caller: the whole club, a squad they're in, or them.
create or replace function workout_is_for_me(p_workout uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from coach_workouts w
    join profiles me on me.id = auth.uid() and me.club_id = w.club_id
    where w.id = p_workout
      and (
        w.audience = 'club'
        or exists (select 1 from coach_workout_targets t where t.workout_id = w.id and t.user_id = me.id)
        or exists (
          select 1 from coach_workout_targets t
          join squad_members sm on sm.squad_id = t.squad_id and sm.user_id = me.id
          where t.workout_id = w.id
        )
      )
  );
$$;

alter table coach_workouts enable row level security;
alter table coach_workout_targets enable row level security;
drop policy if exists read_coach_or_assigned on coach_workouts;
create policy read_coach_or_assigned on coach_workouts for select to authenticated
  using (is_club_coach(club_id) or workout_is_for_me(id));
drop policy if exists read_coach_or_assigned on coach_workout_targets;
create policy read_coach_or_assigned on coach_workout_targets for select to authenticated
  using (exists (
    select 1 from coach_workouts w
    where w.id = workout_id and (is_club_coach(w.club_id) or workout_is_for_me(w.id))
  ));

-- MARK: - 6. Practices and attendance (Phase 3 adds the write functions)

create table if not exists practices (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references clubs on delete cascade,
  -- Practices made together as a weekly series share this id.
  series_id  uuid,
  starts_at  timestamptz not null,
  ends_at    timestamptz not null check (ends_at > starts_at),
  place      text check (place is null or char_length(place) <= 80),
  remind     boolean not null default true,
  cancelled  boolean not null default false,
  created_by uuid references profiles on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists practices_club_start on practices (club_id, starts_at);

-- Empty for a whole-club practice.
create table if not exists practice_squads (
  practice_id uuid not null references practices on delete cascade,
  squad_id    uuid not null references squads on delete cascade,
  primary key (practice_id, squad_id)
);

-- The rower's own answer (decision 39): going or not, an optional reason only coaches see, and
-- a check-in on the day.
create table if not exists attendance_responses (
  practice_id   uuid not null references practices on delete cascade,
  user_id       uuid not null references profiles on delete cascade,
  answer        text check (answer is null or answer in ('going', 'cant')),
  reason        text check (reason is null or char_length(reason) <= 200),
  checked_in_at timestamptz,
  updated_at    timestamptz not null default now(),
  primary key (practice_id, user_id)
);

-- The coach's mark, which always counts; who set it and when (decision 39).
create table if not exists attendance_marks (
  practice_id uuid not null references practices on delete cascade,
  user_id     uuid not null references profiles on delete cascade,
  mark        text not null check (mark in ('present', 'late', 'absent', 'excused')),
  set_by      uuid references profiles on delete set null,
  set_at      timestamptz not null default now(),
  primary key (practice_id, user_id)
);

-- Every mark ever set, so an override stays visible ("Present → Late at 17:45").
create table if not exists attendance_mark_log (
  id          bigint generated always as identity primary key,
  practice_id uuid not null references practices on delete cascade,
  user_id     uuid not null references profiles on delete cascade,
  mark        text not null check (mark in ('present', 'late', 'absent', 'excused')),
  set_by      uuid references profiles on delete set null,
  set_at      timestamptz not null default now()
);

-- Term dates for attendance totals, set by the club's coaches.
create table if not exists club_terms (
  id        uuid primary key default gen_random_uuid(),
  club_id   uuid not null references clubs on delete cascade,
  name      text not null check (char_length(btrim(name)) between 1 and 40),
  starts_on date not null,
  ends_on   date not null check (ends_on >= starts_on)
);

-- Whether a practice is for the caller: the whole club, or a squad they're in.
create or replace function practice_is_for_me(p_practice uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from practices pr
    join profiles me on me.id = auth.uid() and me.club_id = pr.club_id
    where pr.id = p_practice
      and (
        not exists (select 1 from practice_squads ps where ps.practice_id = pr.id)
        or exists (
          select 1 from practice_squads ps
          join squad_members sm on sm.squad_id = ps.squad_id and sm.user_id = me.id
          where ps.practice_id = pr.id
        )
      )
  );
$$;

alter table practices enable row level security;
alter table practice_squads enable row level security;
alter table attendance_responses enable row level security;
alter table attendance_marks enable row level security;
alter table attendance_mark_log enable row level security;
alter table club_terms enable row level security;

drop policy if exists read_coach_or_invited on practices;
create policy read_coach_or_invited on practices for select to authenticated
  using (is_club_coach(club_id) or practice_is_for_me(id));
drop policy if exists read_coach_or_invited on practice_squads;
create policy read_coach_or_invited on practice_squads for select to authenticated
  using (exists (
    select 1 from practices pr where pr.id = practice_id and (is_club_coach(pr.club_id) or practice_is_for_me(pr.id))
  ));
-- Your own answer and mark; a coach sees everyone's in their club.
drop policy if exists read_own_or_coach on attendance_responses;
create policy read_own_or_coach on attendance_responses for select to authenticated
  using (user_id = auth.uid() or exists (
    select 1 from practices pr where pr.id = practice_id and is_club_coach(pr.club_id)
  ));
drop policy if exists read_own_or_coach on attendance_marks;
create policy read_own_or_coach on attendance_marks for select to authenticated
  using (user_id = auth.uid() or exists (
    select 1 from practices pr where pr.id = practice_id and is_club_coach(pr.club_id)
  ));
drop policy if exists read_own_or_coach on attendance_mark_log;
create policy read_own_or_coach on attendance_mark_log for select to authenticated
  using (user_id = auth.uid() or exists (
    select 1 from practices pr where pr.id = practice_id and is_club_coach(pr.club_id)
  ));
drop policy if exists read_own_club on club_terms;
create policy read_own_club on club_terms for select to authenticated
  using (club_id = (select p.club_id from profiles p where p.id = auth.uid()));

-- MARK: - Access to the functions

revoke all on function set_club_coach(uuid, boolean) from public, anon;
grant execute on function set_club_coach(uuid, boolean) to authenticated;
revoke all on function sessions_i_can_interact_with(uuid[]) from public, anon;
grant execute on function sessions_i_can_interact_with(uuid[]) to authenticated;
revoke all on function club_for_invite_code(text) from public, anon;
grant execute on function club_for_invite_code(text) to authenticated;
revoke all on function create_squad(text) from public, anon;
grant execute on function create_squad(text) to authenticated;
revoke all on function rename_squad(uuid, text) from public, anon;
grant execute on function rename_squad(uuid, text) to authenticated;
revoke all on function delete_squad(uuid) from public, anon;
grant execute on function delete_squad(uuid) to authenticated;
revoke all on function set_squad_members(uuid, uuid[]) from public, anon;
grant execute on function set_squad_members(uuid, uuid[]) to authenticated;

commit;
