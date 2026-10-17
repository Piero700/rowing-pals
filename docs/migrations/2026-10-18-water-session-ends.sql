-- Rowing Pals: water sessions end, and rowers see them (decision 79, 2026-10-18).
-- Run on staging after 2026-10-16-boats.sql. Safe to run twice.
--
-- 1. A water session has an end (Starts and Ends, like a practice). Existing sessions end two hours
--    after they start. The rower's Feed shows a boat until its session ends.
-- 2. Owners, co-owners and admins read the club's water sessions and boats, as coaches already do,
--    for "Whole club" in their Calendar. Rowers still read only sent boats they're in.

begin;

-- MARK: - 1. Ends

alter table water_sessions add column if not exists ends_at timestamptz;
update water_sessions set ends_at = starts_at + interval '2 hours' where ends_at is null;

-- A session saved without an end (an older app) ends two hours after it starts; an end must come
-- after the start.
create or replace function water_session_default_end()
returns trigger
language plpgsql as $$
begin
  new.ends_at := coalesce(new.ends_at, new.starts_at + interval '2 hours');
  if new.ends_at <= new.starts_at then raise exception 'A session has to end after it starts.'; end if;
  return new;
end $$;

drop trigger if exists water_sessions_default_end on water_sessions;
create trigger water_sessions_default_end before insert or update of starts_at, ends_at on water_sessions
  for each row execute function water_session_default_end();

alter table water_sessions alter column ends_at set not null;

-- As in 2026-10-16, with the end. The old signature stays for an app that doesn't send one yet.
create or replace function save_water_session(
  p_session uuid, p_title text, p_starts_at timestamptz, p_ends_at timestamptz, p_meet_at text, p_plan text,
  p_practice uuid, p_event uuid
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid := p_session;
  v_practice uuid := p_practice;
  v_ends timestamptz := coalesce(p_ends_at, p_starts_at + interval '2 hours');
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then raise exception 'Only your club''s coaches can set water sessions.'; end if;
  if v_ends <= p_starts_at then raise exception 'A session has to end after it starts.'; end if;
  if v_practice is null and p_event is null then
    select pr.id into v_practice from practices pr
    where pr.club_id = v_club and not pr.cancelled
      and p_starts_at >= pr.starts_at - interval '30 minutes' and p_starts_at < pr.ends_at
    order by abs(extract(epoch from pr.starts_at - p_starts_at)) limit 1;
  end if;
  if v_id is null then
    insert into water_sessions (club_id, practice_id, event_id, title, starts_at, ends_at, meet_at, plan, created_by)
    values (v_club, v_practice, p_event, btrim(p_title), p_starts_at, v_ends,
            nullif(btrim(coalesce(p_meet_at, '')), ''), nullif(btrim(coalesce(p_plan, '')), ''), auth.uid())
    returning id into v_id;
  else
    update water_sessions ws set
      title = btrim(p_title), starts_at = p_starts_at, ends_at = v_ends,
      meet_at = nullif(btrim(coalesce(p_meet_at, '')), ''), plan = nullif(btrim(coalesce(p_plan, '')), ''),
      -- A race keeps its race; otherwise the practice follows the time.
      practice_id = case when ws.event_id is not null then ws.practice_id else v_practice end
    where ws.id = v_id and ws.club_id = v_club;
    if not found then raise exception 'That water session no longer exists.'; end if;
  end if;
  return v_id;
end $$;

-- The rower's sent boats whose session hasn't ended by p_from (was: hadn't started).
create or replace function my_boats(p_from timestamptz)
returns setof session_boats
language sql stable security definer set search_path = public as $$
  select b.* from session_boats b
  join water_sessions ws on ws.id = b.session_id
  join session_boat_seats s on s.boat_id = b.id and s.user_id = auth.uid()
  where b.sent_at is not null and ws.ends_at >= p_from
  order by ws.starts_at;
$$;

-- MARK: - 2. Who reads the club's water sessions

-- Coaches, and the owner, co-owners and admins (decision 79).
create or replace function can_see_club_water(p_club uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select is_club_coach(p_club) or is_club_manager(p_club, 'admin');
$$;

drop policy if exists read_coach_or_crew on water_sessions;
create policy read_coach_or_crew on water_sessions for select to authenticated
  using (can_see_club_water(club_id) or in_my_sent_session(id));
drop policy if exists read_coach_or_crew on session_boats;
create policy read_coach_or_crew on session_boats for select to authenticated
  using (in_my_sent_boat(id) or exists (
    select 1 from water_sessions ws where ws.id = session_id and can_see_club_water(ws.club_id)
  ));
drop policy if exists read_coach_or_crew on session_boat_seats;
create policy read_coach_or_crew on session_boat_seats for select to authenticated
  using (in_my_sent_boat(boat_id) or exists (
    select 1 from session_boats b join water_sessions ws on ws.id = b.session_id
    where b.id = boat_id and can_see_club_water(ws.club_id)
  ));

revoke all on function save_water_session(uuid, text, timestamptz, timestamptz, text, text, uuid, uuid) from public, anon;
grant execute on function save_water_session(uuid, text, timestamptz, timestamptz, text, text, uuid, uuid) to authenticated;
revoke all on function can_see_club_water(uuid) from public, anon;
grant execute on function can_see_club_water(uuid) to authenticated;
revoke all on function water_session_default_end() from public, anon, authenticated;

commit;
