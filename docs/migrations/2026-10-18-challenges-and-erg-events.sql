-- Challenges and erg events (v1.2, user 2026-10-18; decision 91).
-- Run once in the Supabase SQL editor, staging first. Safe to run again.
--
-- Challenges: a club's coaches, owner, co-owners and admins set one, and every rower in the club is
-- in it. Three kinds, all on erg metres on the leaderboards (as Rankings) between two days:
--   target     — each rower aims for the same number of metres ("Row 100km in November");
--   club_total — the club together towards one number ("2,000km as a club this term");
--   squads     — two or more squads race on metres per rower.
-- Erg events: a set piece (a distance or a time) rowed in a window ("Club 2k day, Sat 9–12"). A rower
-- posting a matching piece during it (or up to six hours after) can count it for the event; the
-- event's board shows each rower's best.
--
-- The new tables link only to their club: who set them is kept as a plain id, so the API doesn't
-- gain a second way between clubs and profiles (see 2026-10-04-club-tests.sql).

begin;

-- Coaches, the owner, co-owners and admins of the club.
create or replace function can_set_challenges(p_club uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select is_club_coach(p_club) or exists (
    select 1 from profiles p where p.id = auth.uid() and p.club_id = p_club
      and p.club_role in ('owner', 'co_owner', 'admin')
  );
$$;

-- MARK: - Challenges

create table if not exists challenges (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references clubs on delete cascade,
  kind       text not null check (kind in ('target', 'club_total', 'squads')),
  title      text not null check (char_length(btrim(title)) between 1 and 60),
  target_m   int check (target_m between 1000 and 100000000),
  squad_ids  uuid[] not null default '{}',
  starts_on  date not null,
  ends_on    date not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  constraint challenges_dates check (ends_on >= starts_on and ends_on - starts_on <= 366),
  constraint challenges_shape check (
    (kind in ('target', 'club_total') and target_m is not null)
    or (kind = 'squads' and cardinality(squad_ids) >= 2)
  )
);
create index if not exists challenges_club_idx on challenges (club_id, ends_on desc);
alter table challenges enable row level security;
drop policy if exists read_own_club on challenges;
create policy read_own_club on challenges for select to authenticated
  using (club_id = (select p.club_id from profiles p where p.id = auth.uid()));

-- Saves a challenge, new (p_id null) or changed; returns its id.
create or replace function save_challenge(
  p_id uuid, p_kind text, p_title text, p_target_m int, p_squads uuid[], p_starts date, p_ends date
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid := p_id;
  v_squads uuid[] := array(select distinct s from unnest(coalesce(p_squads, '{}')) s where s is not null);
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not can_set_challenges(v_club) then
    raise exception 'Only your club''s coaches, owner, co-owners and admins can set challenges.';
  end if;
  if coalesce(p_kind, '') not in ('target', 'club_total', 'squads') then raise exception 'Choose the kind of challenge.'; end if;
  if char_length(btrim(coalesce(p_title, ''))) = 0 then raise exception 'Give the challenge a name.'; end if;
  if p_starts is null or p_ends is null or p_ends < p_starts then raise exception 'The challenge has to end on or after the day it starts.'; end if;
  if p_kind in ('target', 'club_total') and coalesce(p_target_m, 0) < 1000 then raise exception 'Set the metres to aim for.'; end if;
  if p_kind = 'squads' then
    if cardinality(v_squads) < 2 then raise exception 'Choose at least two squads.'; end if;
    if exists (select 1 from unnest(v_squads) s where not exists (select 1 from squads q where q.id = s and q.club_id = v_club)) then
      raise exception 'Choose squads from your club.';
    end if;
  else
    v_squads := '{}';
  end if;
  if v_id is null then
    insert into challenges (club_id, kind, title, target_m, squad_ids, starts_on, ends_on, created_by)
    values (v_club, p_kind, btrim(p_title), case when p_kind = 'squads' then null else p_target_m end, v_squads, p_starts, p_ends, auth.uid())
    returning id into v_id;
  else
    update challenges set kind = p_kind, title = btrim(p_title),
                          target_m = case when p_kind = 'squads' then null else p_target_m end,
                          squad_ids = v_squads, starts_on = p_starts, ends_on = p_ends
    where id = v_id and club_id = v_club;
    if not found then raise exception 'That challenge no longer exists.'; end if;
  end if;
  return v_id;
end $$;

create or replace function delete_challenge(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from challenges c where c.id = p_id and can_set_challenges(c.club_id);
end $$;

-- Every rower in the challenge's club with their metres on the leaderboards between its days, and
-- the squads they're in. Only for someone in that club.
create or replace function challenge_standings(p_challenge uuid)
returns table (user_id uuid, display_name text, metres int, squad_ids uuid[])
language plpgsql stable security definer set search_path = public as $$
declare
  v challenges;
begin
  select * into v from challenges where id = p_challenge;
  if v.id is null or v.club_id is distinct from (select p.club_id from profiles p where p.id = auth.uid()) then
    return;
  end if;
  return query
    select p.id, p.display_name,
           coalesce((select sum(d.ranked_erg_distance_m) from daily_totals d
                     where d.user_id = p.id and d.day >= v.starts_on and d.day <= v.ends_on), 0)::int,
           coalesce((select array_agg(m.squad_id) from squad_members m
                     join squads q on q.id = m.squad_id and q.club_id = v.club_id
                     where m.user_id = p.id), '{}')
    from profiles p
    where p.club_id = v.club_id and p.is_rower;
end $$;

-- MARK: - Erg events

create table if not exists erg_events (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references clubs on delete cascade,
  title       text not null check (char_length(btrim(title)) between 1 and 60),
  distance_m  int check (distance_m between 100 and 100000),
  duration_ms int check (duration_ms between 30000 and 7200000),
  starts_at   timestamptz not null,
  ends_at     timestamptz not null,
  created_by  uuid,
  created_at  timestamptz not null default now(),
  constraint erg_events_one_piece check ((distance_m is null) <> (duration_ms is null)),
  constraint erg_events_window check (ends_at > starts_at and ends_at - starts_at <= interval '14 days')
);
create index if not exists erg_events_club_idx on erg_events (club_id, starts_at desc);
alter table erg_events enable row level security;
drop policy if exists read_own_club on erg_events;
create policy read_own_club on erg_events for select to authenticated
  using (club_id = (select p.club_id from profiles p where p.id = auth.uid()));

-- A post can count for one erg event.
alter table sessions add column if not exists erg_event_id uuid references erg_events on delete set null;
create index if not exists sessions_erg_event_idx on sessions (erg_event_id) where erg_event_id is not null;

create or replace function save_erg_event(
  p_id uuid, p_title text, p_distance_m int, p_duration_ms int, p_starts timestamptz, p_ends timestamptz
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid := p_id;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not can_set_challenges(v_club) then
    raise exception 'Only your club''s coaches, owner, co-owners and admins can set erg events.';
  end if;
  if char_length(btrim(coalesce(p_title, ''))) = 0 then raise exception 'Give the event a name.'; end if;
  if (p_distance_m is null) = (p_duration_ms is null) then raise exception 'Set the piece: a distance or a time.'; end if;
  if p_starts is null or p_ends is null or p_ends <= p_starts then raise exception 'The event has to end after it starts.'; end if;
  if v_id is null then
    insert into erg_events (club_id, title, distance_m, duration_ms, starts_at, ends_at, created_by)
    values (v_club, btrim(p_title), p_distance_m, p_duration_ms, p_starts, p_ends, auth.uid())
    returning id into v_id;
  else
    update erg_events set title = btrim(p_title), distance_m = p_distance_m, duration_ms = p_duration_ms,
                          starts_at = p_starts, ends_at = p_ends
    where id = v_id and club_id = v_club;
    if not found then raise exception 'That event no longer exists.'; end if;
  end if;
  return v_id;
end $$;

create or replace function delete_erg_event(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from erg_events e where e.id = p_id and can_set_challenges(e.club_id);
end $$;

-- The event's board: each rower in the club's best piece counted for it — posted from its start to
-- six hours after its end, the right distance exactly (a monitor stops on it) or the right time
-- within the finish-line tolerance tests use. Fastest first for a distance; furthest first for a
-- time. Only for someone in that club.
create or replace function erg_event_board(p_event uuid)
returns table (user_id uuid, display_name text, gender rower_gender, category rower_category,
               distance_m int, time_ms int, session_id uuid)
language plpgsql stable security definer set search_path = public as $$
declare
  e erg_events;
begin
  select * into e from erg_events where id = p_event;
  if e.id is null or e.club_id is distinct from (select p.club_id from profiles p where p.id = auth.uid()) then
    return;
  end if;
  return query
    select distinct on (s.user_id)
           s.user_id, p.display_name, p.gender, p.category, g.distance_m, g.time_ms, s.id
    from sessions s
    join profiles p on p.id = s.user_id and p.club_id = e.club_id and p.is_rower
    join lateral (
      select x.distance_m, x.time_ms from segments x
      where x.session_id = s.id
      order by x.is_lead desc, (x.label = 'main') desc, x.position
      limit 1
    ) g on true
    where s.erg_event_id = e.id
      -- Photographed pieces only, as for tests: a manual entry can't be checked.
      and s.photo_verified
      and s.posted_at >= e.starts_at and s.posted_at <= e.ends_at + interval '6 hours'
      and (
        (e.distance_m is not null and g.distance_m = e.distance_m)
        or (e.duration_ms is not null
            and abs(g.time_ms - e.duration_ms) <= greatest(least(2000, e.duration_ms / 20), e.duration_ms / 100))
      )
    order by s.user_id,
             case when e.distance_m is not null then g.time_ms else -g.distance_m end;
end $$;

-- MARK: - Access to the functions

revoke all on function can_set_challenges(uuid) from public, anon;
grant execute on function can_set_challenges(uuid) to authenticated;
revoke all on function save_challenge(uuid, text, text, int, uuid[], date, date) from public, anon;
grant execute on function save_challenge(uuid, text, text, int, uuid[], date, date) to authenticated;
revoke all on function delete_challenge(uuid) from public, anon;
grant execute on function delete_challenge(uuid) to authenticated;
revoke all on function challenge_standings(uuid) from public, anon;
grant execute on function challenge_standings(uuid) to authenticated;
revoke all on function save_erg_event(uuid, text, int, int, timestamptz, timestamptz) from public, anon;
grant execute on function save_erg_event(uuid, text, int, int, timestamptz, timestamptz) to authenticated;
revoke all on function delete_erg_event(uuid) from public, anon;
grant execute on function delete_erg_event(uuid) to authenticated;
revoke all on function erg_event_board(uuid) from public, anon;
grant execute on function erg_event_board(uuid) to authenticated;

commit;

-- The API sees the new tables, column and functions straight away.
notify pgrst, 'reload schema';
