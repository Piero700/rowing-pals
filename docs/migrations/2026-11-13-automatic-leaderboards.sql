-- Automatic leaderboards (decision 104, user 2026-11-13). Run once in the Supabase SQL editor,
-- staging first, BEFORE installing the build that needs it (posting writes the new segment columns).
-- Safe to run again: the back-fill skips any result a session already has.
--
-- What it does:
--   1. segments.is_interval, rep_times_ms and rep_distances_m: an interval workout, and each of its
--      reps as read off the monitor (and any next screens joined onto it), so every rep can rank.
--   2. ranking_tests(club): the nine standard tests plus a club's own, with their targets.
--   3. backfill_test_results(): ranks every photographed post made before this by the app's rules
--      (Rowing Pals/Core/Services/AutoRanking.swift): each Main or Extra piece, or interval rep, at
--      a test's distance or time puts the session's best for that test on its leaderboard, whatever
--      its rate, zone or Session type. Warm-ups and cool-downs never rank, nor does an interval
--      workout's total. Results are dated when the session was rowed, and a result that beat every
--      earlier one for its test makes the post a new PB (no alerts are sent for old posts).
--
-- Limits of the back-fill, said plainly:
--   * Posts from before this build kept no rep times, so an old interval session's reps can't be
--     ranked (its total isn't either). Its photos are still in Storage; re-reading them needs the app.
--   * Before 5 Nov an interval workout was only marked when its title gave a rep distance
--     ("8x500m"). An old timed-rep workout (3 x 10:00) can't be told from one continuous piece, so
--     its total could rank (a 3 x 10:00 as a 30min). Delete that result from the post if it shows.

begin;

-- MARK: - 1. Reps on posted pieces

alter table segments add column if not exists is_interval boolean not null default false;
alter table segments add column if not exists rep_times_ms int[];
alter table segments add column if not exists rep_distances_m int[];

alter table segments drop constraint if exists segments_reps_valid;
alter table segments add constraint segments_reps_valid check (
  (rep_times_ms is null and rep_distances_m is null)
  or (cardinality(rep_times_ms) = cardinality(rep_distances_m)
      and cardinality(rep_times_ms) between 1 and 100
      and 0 < all (rep_times_ms) and 0 < all (rep_distances_m))
);

-- Older interval posts: the ones whose title gave a rep distance.
update segments set is_interval = true where rep_distance_m is not null and not is_interval;

-- MARK: - 2. The tests a piece can rank on

create or replace function ranking_tests(p_club uuid)
returns table (key text, distance_m int, duration_ms int)
language sql stable set search_path = public as $$
  select v.key, v.distance_m, v.duration_ms
  from (values
    ('500m', 500, null::int), ('1k', 1000, null), ('2k', 2000, null), ('5k', 5000, null),
    ('6k', 6000, null), ('10k', 10000, null),
    ('4min', null, 240000), ('30min', null, 1800000), ('60min', null, 3600000)
  ) as v (key, distance_m, duration_ms)
  union all
  select 'club:' || c.id::text, c.distance_m, c.duration_ms
  from club_tests c
  where p_club is not null and c.club_id = p_club
$$;

-- MARK: - 3. Ranking posts made before automatic leaderboards

create or replace function backfill_test_results()
returns table (sessions_ranked int, results_added int, new_pbs int)
language plpgsql security definer set search_path = public as $$
declare
  s record;
  p profiles%rowtype;
  r record;
  v_sessions int := 0;
  v_results int := 0;
  v_pbs int := 0;
  v_added boolean;
  v_pb boolean;
  v_earlier_count int;
  v_earlier_max_m int;
  v_earlier_min_ms bigint;
begin
  for s in
    select * from sessions
    where photo_verified and coalesce(is_ranked, false) and type = 'erg'
    order by captured_at, posted_at
  loop
    select * into p from profiles where id = s.user_id;
    if not found or p.gender is null or p.category is null then continue; end if;
    v_added := false;
    v_pb := false;

    for r in
      with efforts as (
        -- A whole piece, when it isn't an interval workout.
        select g.id as segment_id, g.distance_m, g.time_ms::bigint as time_ms
        from segments g
        where g.session_id = s.id and g.label in ('main', 'extra')
          and g.monitor_photo_path is not null and not g.is_interval
        union all
        -- Each rep of an interval workout.
        select g.id, rep.d, rep.t::bigint
        from segments g
        cross join lateral unnest(g.rep_distances_m, g.rep_times_ms) as rep (d, t)
        where g.session_id = s.id and g.label in ('main', 'extra')
          and g.monitor_photo_path is not null and g.is_interval
      ),
      matched as (
        select t.key, (t.duration_ms is not null) as by_time, e.segment_id, e.distance_m, e.time_ms
        from efforts e
        join ranking_tests(p.club_id) t
          on (t.distance_m is not null and e.distance_m = t.distance_m)
          or (t.duration_ms is not null
              and abs(e.time_ms - t.duration_ms)
                  <= greatest(least(2000, t.duration_ms / 20), t.duration_ms / 100))
        where e.distance_m > 0 and e.time_ms > 0
      )
      -- The session's best for each test: furthest for a timed test, fastest otherwise.
      select distinct on (key) key, by_time, segment_id, distance_m, time_ms
      from matched
      order by key, case when by_time then -distance_m::bigint else time_ms end
    loop
      if exists (select 1 from test_results where session_id = s.id and distance_key = r.key) then
        continue;
      end if;

      select count(*), max(tr.distance_m), min(tr.time_ms)
      into v_earlier_count, v_earlier_max_m, v_earlier_min_ms
      from test_results tr
      join sessions ps on ps.id = tr.session_id
      where tr.user_id = s.user_id and tr.distance_key = r.key and ps.captured_at < s.captured_at;

      if v_earlier_count = 0
         or (r.by_time and r.distance_m > v_earlier_max_m)
         or (not r.by_time and r.time_ms < v_earlier_min_ms) then
        v_pb := true;
      end if;

      insert into test_results (
        user_id, session_id, segment_id, distance_key, distance_m, time_ms, split_ms,
        gender_at_time, category_at_time, set_at
      ) values (
        s.user_id, s.id, r.segment_id, r.key, r.distance_m, r.time_ms,
        round(r.time_ms / (r.distance_m / 500.0))::int,
        p.gender, p.category, s.captured_at
      );
      v_results := v_results + 1;
      v_added := true;
    end loop;

    if v_added then v_sessions := v_sessions + 1; end if;
    if v_pb and not s.is_new_pb then
      update sessions set is_new_pb = true where id = s.id;
      v_pbs := v_pbs + 1;
    end if;
  end loop;

  return query select v_sessions, v_results, v_pbs;
end $$;

-- Run from the SQL editor only, never from the app.
revoke all on function backfill_test_results() from public, anon, authenticated;
revoke all on function ranking_tests(uuid) from public, anon;
grant execute on function ranking_tests(uuid) to authenticated;

commit;

-- MARK: - Run the back-fill (shows how many posts, results and PBs it added)

select * from backfill_test_results();
