-- Coach version, phase CV3: boats and water sessions (decisions 67, 70; user 2026-10-16).
-- Run once in the Supabase SQL editor, staging first, after 2026-10-16-calendar.sql. Safe to run
-- again.
--
-- What it adds:
--   1. Saved boats: crews a club puts out again and again (decision 70).
--   2. Water sessions: a coach's plan on the river, its boats and who sits where. Seat 1 is bow,
--      the highest seat is stroke, seat 0 is the cox. Nobody logs water metres (decision 54).
--   3. Sending: each rower in a boat is told their boat and seat; it shows on their Feed until
--      the session. Changing a sent boat makes it "Not sent" again until it's re-sent.
--   4. The "boat_seat" alert.

begin;

-- MARK: - Boat types

-- 1x 2x 2- 4- 4+ 4x 8+ (the app shows a real minus sign).
create or replace function boat_rowers(p_type text)
returns int
language sql immutable as $$
  select case p_type when '1x' then 1 when '2x' then 2 when '2-' then 2
                     when '4-' then 4 when '4+' then 4 when '4x' then 4 when '8+' then 8 end;
$$;

create or replace function boat_is_coxed(p_type text)
returns boolean
language sql immutable as $$
  select p_type in ('4+', '8+');
$$;

-- MARK: - 1. Saved boats (decision 70)

create table if not exists saved_boats (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references clubs on delete cascade,
  name       text not null check (char_length(btrim(name)) between 1 and 40),
  boat_type  text not null check (boat_type in ('1x', '2x', '2-', '4-', '4+', '4x', '8+')),
  rigging    text not null default 'stroke' check (rigging in ('stroke', 'bow')),
  created_by uuid references profiles on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists saved_boats_club on saved_boats (club_id);

create table if not exists saved_boat_seats (
  saved_boat_id uuid not null references saved_boats on delete cascade,
  seat          int not null check (seat between 0 and 8),
  user_id       uuid not null references profiles on delete cascade,
  primary key (saved_boat_id, seat),
  unique (saved_boat_id, user_id)
);

-- MARK: - 2. Water sessions, their boats and seats

create table if not exists water_sessions (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references clubs on delete cascade,
  -- Who can go comes from this practice's answers, or this race's "Can you race?".
  practice_id uuid references practices on delete set null,
  event_id    uuid references club_events on delete set null,
  title       text not null check (char_length(btrim(title)) between 1 and 80),
  starts_at   timestamptz not null,
  meet_at     text check (meet_at is null or char_length(meet_at) <= 80),
  plan        text check (plan is null or char_length(plan) <= 600),
  created_by  uuid references profiles on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists water_sessions_club_start on water_sessions (club_id, starts_at);

create table if not exists session_boats (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid not null references water_sessions on delete cascade,
  position      int not null default 0,
  name          text not null check (char_length(btrim(name)) between 1 and 40),
  boat_type     text not null check (boat_type in ('1x', '2x', '2-', '4-', '4+', '4x', '8+')),
  rigging       text not null default 'stroke' check (rigging in ('stroke', 'bow')),
  saved_boat_id uuid references saved_boats on delete set null,
  -- Null until sent, and again after the crew changes.
  sent_at       timestamptz,
  created_at    timestamptz not null default now()
);
create index if not exists session_boats_session on session_boats (session_id, position);

create table if not exists session_boat_seats (
  boat_id uuid not null references session_boats on delete cascade,
  seat    int not null check (seat between 0 and 8),
  user_id uuid not null references profiles on delete cascade,
  primary key (boat_id, seat),
  unique (boat_id, user_id)
);
create index if not exists session_boat_seats_user on session_boat_seats (user_id);

-- Whether the caller sits in this boat and it has been sent (security definer: no policy loop).
create or replace function in_my_sent_boat(p_boat uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from session_boats b
    join session_boat_seats s on s.boat_id = b.id and s.user_id = auth.uid()
    where b.id = p_boat and b.sent_at is not null
  );
$$;

create or replace function in_my_sent_session(p_session uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from session_boats b
    join session_boat_seats s on s.boat_id = b.id and s.user_id = auth.uid()
    where b.session_id = p_session and b.sent_at is not null
  );
$$;

alter table saved_boats enable row level security;
alter table saved_boat_seats enable row level security;
alter table water_sessions enable row level security;
alter table session_boats enable row level security;
alter table session_boat_seats enable row level security;

-- Coaches read everything of their club; a rower reads a sent boat they're in, its crew and its
-- session. Every write goes through the functions below.
drop policy if exists read_coach on saved_boats;
create policy read_coach on saved_boats for select to authenticated
  using (is_club_coach(club_id));
drop policy if exists read_coach on saved_boat_seats;
create policy read_coach on saved_boat_seats for select to authenticated
  using (exists (select 1 from saved_boats sb where sb.id = saved_boat_id and is_club_coach(sb.club_id)));
drop policy if exists read_coach_or_crew on water_sessions;
create policy read_coach_or_crew on water_sessions for select to authenticated
  using (is_club_coach(club_id) or in_my_sent_session(id));
drop policy if exists read_coach_or_crew on session_boats;
create policy read_coach_or_crew on session_boats for select to authenticated
  using (in_my_sent_boat(id) or exists (
    select 1 from water_sessions ws where ws.id = session_id and is_club_coach(ws.club_id)
  ));
drop policy if exists read_coach_or_crew on session_boat_seats;
create policy read_coach_or_crew on session_boat_seats for select to authenticated
  using (in_my_sent_boat(boat_id) or exists (
    select 1 from session_boats b join water_sessions ws on ws.id = b.session_id
    where b.id = boat_id and is_club_coach(ws.club_id)
  ));

-- Checks a crew: seats within the boat (a cox only in a coxed boat), each a member of the club,
-- nobody twice. p_seats: [{"seat": 1, "user": "<uuid>"}, …]. Internal.
create or replace function check_crew(p_club uuid, p_type text, p_seats jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_item jsonb;
  v_seat int;
begin
  if boat_rowers(p_type) is null then raise exception 'Choose a boat type.'; end if;
  for v_item in select * from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) loop
    v_seat := (v_item ->> 'seat')::int;
    if v_seat < 0 or v_seat > boat_rowers(p_type) or (v_seat = 0 and not boat_is_coxed(p_type)) then
      raise exception 'That seat isn''t in this boat.';
    end if;
    if not exists (select 1 from profiles p where p.id = (v_item ->> 'user')::uuid and p.club_id = p_club) then
      raise exception 'Everyone in a boat has to be in your club.';
    end if;
  end loop;
  if (select count(distinct v ->> 'user') from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v)
     <> jsonb_array_length(coalesce(p_seats, '[]'::jsonb)) then
    raise exception 'Someone is in two seats.';
  end if;
end $$;

-- MARK: - Saved boats

create or replace function save_saved_boat(p_saved uuid, p_name text, p_type text, p_rigging text, p_seats jsonb)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid := p_saved;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then raise exception 'Only your club''s coaches can save boats.'; end if;
  perform check_crew(v_club, p_type, p_seats);
  if v_id is null then
    insert into saved_boats (club_id, name, boat_type, rigging, created_by)
    values (v_club, btrim(p_name), p_type, coalesce(p_rigging, 'stroke'), auth.uid())
    returning id into v_id;
  else
    update saved_boats set name = btrim(p_name), boat_type = p_type, rigging = coalesce(p_rigging, 'stroke')
    where id = v_id and club_id = v_club;
    if not found then raise exception 'That saved boat no longer exists.'; end if;
    delete from saved_boat_seats where saved_boat_id = v_id;
  end if;
  insert into saved_boat_seats (saved_boat_id, seat, user_id)
    select v_id, (v ->> 'seat')::int, (v ->> 'user')::uuid from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v;
  return v_id;
end $$;

create or replace function delete_saved_boat(p_saved uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from saved_boats sb where sb.id = p_saved and is_club_coach(sb.club_id);
end $$;

-- MARK: - Water sessions

-- New (p_session null) or changed. With no practice or race given, the session takes its answers
-- from the club's practice at that time, if there is one.
create or replace function save_water_session(
  p_session uuid, p_title text, p_starts_at timestamptz, p_meet_at text, p_plan text,
  p_practice uuid, p_event uuid
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid := p_session;
  v_practice uuid := p_practice;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then raise exception 'Only your club''s coaches can set water sessions.'; end if;
  if v_practice is null and p_event is null then
    select pr.id into v_practice from practices pr
    where pr.club_id = v_club and not pr.cancelled
      and p_starts_at >= pr.starts_at - interval '30 minutes' and p_starts_at < pr.ends_at
    order by abs(extract(epoch from pr.starts_at - p_starts_at)) limit 1;
  end if;
  if v_id is null then
    insert into water_sessions (club_id, practice_id, event_id, title, starts_at, meet_at, plan, created_by)
    values (v_club, v_practice, p_event, btrim(p_title), p_starts_at,
            nullif(btrim(coalesce(p_meet_at, '')), ''), nullif(btrim(coalesce(p_plan, '')), ''), auth.uid())
    returning id into v_id;
  else
    update water_sessions ws set
      title = btrim(p_title), starts_at = p_starts_at,
      meet_at = nullif(btrim(coalesce(p_meet_at, '')), ''), plan = nullif(btrim(coalesce(p_plan, '')), ''),
      -- A race keeps its race; otherwise the practice follows the time.
      practice_id = case when ws.event_id is not null then ws.practice_id else v_practice end
    where ws.id = v_id and ws.club_id = v_club;
    if not found then raise exception 'That water session no longer exists.'; end if;
  end if;
  return v_id;
end $$;

create or replace function delete_water_session(p_session uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from water_sessions ws where ws.id = p_session and is_club_coach(ws.club_id);
end $$;

-- A boat in a session, new (p_boat null) or changed. A sent boat whose name, type, rigging or crew
-- changes goes back to "Not sent". Nobody can be in two boats of one session. p_keep_saved: keep
-- this crew in Saved boats (made the first time, then kept in step); false unlinks it.
create or replace function save_session_boat(
  p_boat uuid, p_session uuid, p_name text, p_type text, p_rigging text, p_seats jsonb, p_keep_saved boolean
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_session water_sessions;
  v_id uuid := p_boat;
  v_old session_boats;
  v_old_seats jsonb;
  v_new_seats jsonb;
  v_clash text;
  v_saved uuid;
begin
  select * into v_session from water_sessions where id = p_session;
  if v_session.id is null then raise exception 'That water session no longer exists.'; end if;
  if not is_club_coach(v_session.club_id) then raise exception 'Only your club''s coaches can crew boats.'; end if;
  perform check_crew(v_session.club_id, p_type, p_seats);

  select p.display_name || ' is already in ' || b.name into v_clash
  from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v
  join session_boat_seats s on s.user_id = (v ->> 'user')::uuid
  join session_boats b on b.id = s.boat_id and b.session_id = p_session and b.id is distinct from p_boat
  join profiles p on p.id = s.user_id
  limit 1;
  if v_clash is not null then raise exception '%.', v_clash; end if;

  v_new_seats := coalesce((select jsonb_agg(jsonb_build_object('seat', (v ->> 'seat')::int, 'user', v ->> 'user') order by (v ->> 'seat')::int)
                           from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v), '[]'::jsonb);

  if v_id is null then
    insert into session_boats (session_id, position, name, boat_type, rigging)
    values (p_session, coalesce((select max(position) + 1 from session_boats where session_id = p_session), 0),
            btrim(p_name), p_type, coalesce(p_rigging, 'stroke'))
    returning id into v_id;
  else
    select * into v_old from session_boats where id = v_id and session_id = p_session;
    if v_old.id is null then raise exception 'That boat no longer exists.'; end if;
    v_old_seats := coalesce((select jsonb_agg(jsonb_build_object('seat', s.seat, 'user', s.user_id::text) order by s.seat)
                             from session_boat_seats s where s.boat_id = v_id), '[]'::jsonb);
    update session_boats set
      name = btrim(p_name), boat_type = p_type, rigging = coalesce(p_rigging, 'stroke'),
      sent_at = case when v_old.name = btrim(p_name) and v_old.boat_type = p_type
                          and v_old.rigging = coalesce(p_rigging, 'stroke') and v_old_seats = v_new_seats
                     then v_old.sent_at end
    where id = v_id;
    delete from session_boat_seats where boat_id = v_id;
  end if;
  insert into session_boat_seats (boat_id, seat, user_id)
    select v_id, (v ->> 'seat')::int, (v ->> 'user')::uuid from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v;

  if coalesce(p_keep_saved, false) then
    v_saved := save_saved_boat((select saved_boat_id from session_boats where id = v_id), p_name, p_type, p_rigging, p_seats);
    update session_boats set saved_boat_id = v_saved where id = v_id;
  else
    update session_boats set saved_boat_id = null where id = v_id;
  end if;
  return v_id;
end $$;

-- Adds a saved boat to a session. Anyone already in another boat of the session is left out
-- (their seat stays empty); the coach swaps anyone who can't make it afterwards.
create or replace function add_saved_boat(p_saved uuid, p_session uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_session water_sessions;
  v_saved saved_boats;
  v_id uuid;
begin
  select * into v_session from water_sessions where id = p_session;
  select * into v_saved from saved_boats where id = p_saved;
  if v_session.id is null or v_saved.id is null then raise exception 'That boat or session no longer exists.'; end if;
  if not is_club_coach(v_session.club_id) or v_saved.club_id <> v_session.club_id then
    raise exception 'Only your club''s coaches can crew boats.';
  end if;
  insert into session_boats (session_id, position, name, boat_type, rigging, saved_boat_id)
  values (p_session, coalesce((select max(position) + 1 from session_boats where session_id = p_session), 0),
          v_saved.name, v_saved.boat_type, v_saved.rigging, v_saved.id)
  returning id into v_id;
  insert into session_boat_seats (boat_id, seat, user_id)
    select v_id, s.seat, s.user_id from saved_boat_seats s
    where s.saved_boat_id = p_saved
      and not exists (
        select 1 from session_boat_seats o join session_boats b on b.id = o.boat_id
        where b.session_id = p_session and b.id <> v_id and o.user_id = s.user_id
      );
  return v_id;
end $$;

create or replace function delete_session_boat(p_boat uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from session_boats b using water_sessions ws
  where b.id = p_boat and ws.id = b.session_id and is_club_coach(ws.club_id);
end $$;

-- MARK: - 3. Sending

-- Sends every boat in the session not sent yet: each rower in it is told their boat and seat.
-- Returns how many rowers were told.
create or replace function send_water_session(p_session uuid)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_session water_sessions;
  v_boats uuid[];
  v_count int := 0;
begin
  select * into v_session from water_sessions where id = p_session;
  if v_session.id is null then raise exception 'That water session no longer exists.'; end if;
  if not is_club_coach(v_session.club_id) then raise exception 'Only your club''s coaches can send boats.'; end if;

  select coalesce(array_agg(b.id), '{}') into v_boats from session_boats b
  where b.session_id = p_session and b.sent_at is null
    and exists (select 1 from session_boat_seats s where s.boat_id = b.id);
  update session_boats set sent_at = now() where id = any(v_boats);
  select count(*) into v_count from session_boat_seats s where s.boat_id = any(v_boats);

  begin
    insert into notifications (recipient_id, actor_id, kind, club_id, boat_id)
    select s.user_id, auth.uid(), 'boat_seat', v_session.club_id, s.boat_id
    from session_boat_seats s
    where s.boat_id = any(v_boats)
      and s.user_id <> auth.uid()
      and not exists (
        select 1 from blocks bl
        where (bl.blocker_id = s.user_id and bl.blocked_id = auth.uid())
           or (bl.blocker_id = auth.uid() and bl.blocked_id = s.user_id)
      );
  exception when others then
    -- An alert problem must never stop the boats being sent.
    raise warning 'boat alerts: %', sqlerrm;
  end;
  return v_count;
end $$;

-- The caller's sent boats in sessions from p_from on, soonest first (their Feed).
create or replace function my_boats(p_from timestamptz)
returns setof session_boats
language sql stable security definer set search_path = public as $$
  select b.* from session_boats b
  join water_sessions ws on ws.id = b.session_id
  join session_boat_seats s on s.boat_id = b.id and s.user_id = auth.uid()
  where b.sent_at is not null and ws.starts_at >= p_from
  order by ws.starts_at;
$$;

-- MARK: - 4. The alert

do $$
begin
  if to_regclass('public.notifications') is null then
    raise notice 'No notifications table: run 2026-09-26-notifications.sql, then this file again, for boat alerts.';
    return;
  end if;
  alter table notifications add column if not exists boat_id uuid references session_boats on delete cascade;
  alter table notifications drop constraint if exists notifications_kind_check;
  alter table notifications add constraint notifications_kind_check
    check (kind in ('comment', 'reply', 'pb', 'club_post', 'club_invite', 'new_workout',
                    'new_practice', 'practice_changed', 'practice_cancelled', 'practice_reminder', 'new_event',
                    'boat_seat'));
end $$;

-- MARK: - Who may call what

revoke all on function check_crew(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function in_my_sent_boat(uuid) from public, anon;
grant execute on function in_my_sent_boat(uuid) to authenticated;
revoke all on function in_my_sent_session(uuid) from public, anon;
grant execute on function in_my_sent_session(uuid) to authenticated;
revoke all on function save_saved_boat(uuid, text, text, text, jsonb) from public, anon;
grant execute on function save_saved_boat(uuid, text, text, text, jsonb) to authenticated;
revoke all on function delete_saved_boat(uuid) from public, anon;
grant execute on function delete_saved_boat(uuid) to authenticated;
revoke all on function save_water_session(uuid, text, timestamptz, text, text, uuid, uuid) from public, anon;
grant execute on function save_water_session(uuid, text, timestamptz, text, text, uuid, uuid) to authenticated;
revoke all on function delete_water_session(uuid) from public, anon;
grant execute on function delete_water_session(uuid) to authenticated;
revoke all on function save_session_boat(uuid, uuid, text, text, text, jsonb, boolean) from public, anon;
grant execute on function save_session_boat(uuid, uuid, text, text, text, jsonb, boolean) to authenticated;
revoke all on function add_saved_boat(uuid, uuid) from public, anon;
grant execute on function add_saved_boat(uuid, uuid) to authenticated;
revoke all on function delete_session_boat(uuid) from public, anon;
grant execute on function delete_session_boat(uuid) to authenticated;
revoke all on function send_water_session(uuid) from public, anon;
grant execute on function send_water_session(uuid) to authenticated;
revoke all on function my_boats(timestamptz) from public, anon;
grant execute on function my_boats(timestamptz) to authenticated;

commit;
