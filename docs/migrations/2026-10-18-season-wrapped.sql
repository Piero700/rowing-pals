-- Season Wrapped (v2, user 2026-10-18; decision 92).
-- Run once in the Supabase SQL editor, staging first. Safe to run again. Works before or after
-- 2026-10-18-crew-tags.sql and 2026-10-18-challenges-and-erg-events.sql: the parts that read their
-- tables are left empty until they exist.
--
-- One rower's season between two days (a club term, or dates they choose), worked out for the
-- signed-in rower only:
--   totals and streaks — erg metres, sessions, time on the erg, days rowed, longest streak, biggest
--                        week, busiest month;
--   PBs and tests      — the personal bests set, the best 2k and how much it improved on the best before;
--   club and crew      — their place on their own group's metres in the club, who they trained with
--                        most (crew tags, either way round), personal-target challenges finished;
--   training mix       — time in each zone, and whether they row mornings, afternoons or evenings.

create or replace function season_wrapped(p_from date, p_to date)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_profile profiles;
  v_metres int;
  v_sessions int;
  v_days int;
  v_time bigint;
  v_streak int;
  v_week jsonb;
  v_month jsonb;
  v_pbs jsonb;
  v_best_2k bigint;
  v_best_2k_before bigint;
  v_place jsonb;
  v_mates jsonb := '[]'::jsonb;
  v_challenges jsonb := '[]'::jsonb;
  v_zones jsonb;
  v_times jsonb;
begin
  if v_me is null then raise exception 'Sign in first.'; end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 400 then
    raise exception 'Choose two dates up to a year apart.';
  end if;
  select * into v_profile from profiles where id = v_me;

  -- Totals and streaks.
  select coalesce(sum(d.erg_distance_m), 0), coalesce(sum(d.session_count), 0), count(*) filter (where d.session_count > 0)
    into v_metres, v_sessions, v_days
  from daily_totals d where d.user_id = v_me and d.day between p_from and p_to;

  select coalesce(sum(s.total_time_ms), 0) into v_time
  from sessions s where s.user_id = v_me and s.session_date between p_from and p_to;

  with rowed as (
    select d.day from daily_totals d where d.user_id = v_me and d.day between p_from and p_to and d.session_count > 0
  ), runs as (
    select r.day - (row_number() over (order by r.day))::int as run from rowed r
  )
  select coalesce(max(n), 0) into v_streak from (select count(*) as n from runs group by run) x;

  select jsonb_build_object('start', w.start, 'metres', w.metres) into v_week
  from (
    select date_trunc('week', d.day)::date as start, sum(d.erg_distance_m)::int as metres
    from daily_totals d where d.user_id = v_me and d.day between p_from and p_to
    group by 1 having sum(d.erg_distance_m) > 0 order by 2 desc, 1 limit 1
  ) w;

  select jsonb_build_object('start', m.start, 'metres', m.metres) into v_month
  from (
    select date_trunc('month', d.day)::date as start, sum(d.erg_distance_m)::int as metres
    from daily_totals d where d.user_id = v_me and d.day between p_from and p_to
    group by 1 having sum(d.erg_distance_m) > 0 order by 2 desc, 1 limit 1
  ) m;

  -- PBs and tests.
  select coalesce(jsonb_agg(jsonb_build_object('key', t.distance_key, 'distance_m', t.distance_m, 'time_ms', t.time_ms, 'day', s.session_date)
                            order by s.session_date), '[]'::jsonb)
    into v_pbs
  from sessions s join test_results t on t.session_id = s.id
  where s.user_id = v_me and s.is_new_pb and s.session_date between p_from and p_to;

  select min(t.time_ms) into v_best_2k
  from test_results t join sessions s on s.id = t.session_id
  where t.user_id = v_me and t.distance_key = '2k' and s.session_date between p_from and p_to;

  select min(t.time_ms) into v_best_2k_before
  from test_results t join sessions s on s.id = t.session_id
  where t.user_id = v_me and t.distance_key = '2k' and s.session_date < p_from;

  -- Their place in their own group's metres in the club (the group Rankings opens on).
  if v_profile.club_id is not null and v_profile.is_rower then
    with totals as (
      select p.id, p.created_at, coalesce(sum(d.ranked_erg_distance_m), 0)::int as metres
      from profiles p
      left join daily_totals d on d.user_id = p.id and d.day between p_from and p_to
      where p.club_id = v_profile.club_id and p.is_rower
        and (v_profile.gender is null or (p.gender = v_profile.gender and p.category = v_profile.category))
      group by p.id
    ), me as (select * from totals where id = v_me)
    select case when me.metres > 0 then jsonb_build_object(
             'place', (select count(*) from totals o where o.metres > 0
                       and (o.metres > me.metres or (o.metres = me.metres and (o.created_at, o.id) < (me.created_at, me.id)))) + 1,
             'of', (select count(*) from totals o where o.metres > 0),
             'group', case when v_profile.gender is null then 'rowers in your club'
                           else v_profile.category::text || ' ' || case v_profile.gender when 'M' then 'men' else 'women' end end)
           end
      into v_place
    from me;
  end if;

  -- Who they trained with most: people they tagged, and people who tagged them.
  if to_regclass('public.session_tags') is not null then
    execute $q$
      with pairs as (
        select t.user_id as other from session_tags t join sessions s on s.id = t.session_id
        where s.user_id = $1 and s.session_date between $2 and $3
        union all
        select s.user_id from session_tags t join sessions s on s.id = t.session_id
        where t.user_id = $1 and s.session_date between $2 and $3
      ), counted as (
        select other, count(*)::int as sessions from pairs group by other order by 2 desc limit 3
      )
      select coalesce(jsonb_agg(jsonb_build_object('user_id', c.other, 'name', p.display_name, 'sessions', c.sessions)
                                order by c.sessions desc, p.display_name), '[]'::jsonb)
      from counted c join profiles p on p.id = c.other
    $q$ into v_mates using v_me, p_from, p_to;
  end if;

  -- Personal-target challenges that ended in the season and that they reached.
  if to_regclass('public.challenges') is not null and v_profile.club_id is not null then
    execute $q$
      select coalesce(jsonb_agg(c.title order by c.ends_on), '[]'::jsonb)
      from challenges c
      where c.club_id = $4 and c.kind = 'target' and c.ends_on between $2 and $3
        and (select coalesce(sum(d.ranked_erg_distance_m), 0) from daily_totals d
             where d.user_id = $1 and d.day between c.starts_on and c.ends_on) >= c.target_m
    $q$ into v_challenges using v_me, p_from, p_to, v_profile.club_id;
  end if;

  -- Training mix.
  select coalesce(jsonb_agg(jsonb_build_object('zone', z.zone, 'time_ms', z.ms) order by z.ms desc), '[]'::jsonb)
    into v_zones
  from (
    select coalesce(nullif(s.zone, ''), 'Other') as zone, sum(s.total_time_ms)::bigint as ms
    from sessions s where s.user_id = v_me and s.session_date between p_from and p_to
    group by 1
  ) z;

  select jsonb_build_object(
           'morning', count(*) filter (where extract(hour from s.captured_at at time zone 'Europe/London') < 12),
           'afternoon', count(*) filter (where extract(hour from s.captured_at at time zone 'Europe/London') between 12 and 16),
           'evening', count(*) filter (where extract(hour from s.captured_at at time zone 'Europe/London') >= 17))
    into v_times
  from sessions s where s.user_id = v_me and s.session_date between p_from and p_to;

  return jsonb_build_object(
    'metres', v_metres, 'sessions', v_sessions, 'days', v_days, 'time_ms', v_time, 'longest_streak', v_streak,
    'biggest_week', v_week, 'busiest_month', v_month,
    'pbs', v_pbs, 'best_2k_ms', v_best_2k, 'best_2k_before_ms', v_best_2k_before,
    'club_place', v_place, 'trained_with', v_mates, 'challenges_done', v_challenges,
    'zones', v_zones, 'time_of_day', v_times
  );
end $$;

revoke all on function season_wrapped(date, date) from public, anon;
grant execute on function season_wrapped(date, date) to authenticated;

-- The API sees the new function straight away.
notify pgrst, 'reload schema';
