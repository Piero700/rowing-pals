-- Pace Engine inputs (decisions 30 and 31). Run once in the Supabase SQL editor, staging
-- first. Safe to run again. RUN THIS BEFORE INSTALLING A BUILD THAT INCLUDES IT: new posts
-- write the columns below.
--
-- 1. Every erg session carries its training zone (UT2 / UT1 / AT / TR / AN) — the input the
--    prediction engine needs — and an optional effort rating (RPE, CR10 0–10). Existing posts
--    get a zone from their old "Main workout label" where one maps.
-- 2. A segment can carry its interval rep distance, read off the monitor's workout title
--    ("8x500m/1:00r" -> 500), the single biggest accuracy win for the engine (SPEC.md §7.3).
-- 3. Date of birth and bodyweight live in their own table that only the rower can read —
--    NOT on `profiles`, which every signed-in rower can read. They are private inputs to the
--    prediction algorithm and never shown (decision 30).

-- MARK: - 1. Zone and effort on sessions

alter table sessions add column if not exists zone text;
alter table sessions drop constraint if exists sessions_zone_check;
alter table sessions add constraint sessions_zone_check
  check (zone is null or zone in ('UT2', 'UT1', 'AT', 'TR', 'AN'));

alter table sessions add column if not exists rpe numeric(3, 1);
alter table sessions drop constraint if exists sessions_rpe_check;
alter table sessions add constraint sessions_rpe_check
  check (rpe is null or rpe between 0 and 10);

-- Old labels that name a zone. Intervals and Recovery don't, so those posts stay without one
-- and never reach the engine.
update sessions set zone = case
    when workout_label in ('UT2', 'UT1') then workout_label
    when workout_label = 'Threshold' then 'AT'
    when workout_label = 'Test' or workout_label like '% test' then 'AN'
  end
where zone is null and type = 'erg';

-- MARK: - 2. Interval rep distance on segments

alter table segments add column if not exists rep_distance_m int;
alter table segments drop constraint if exists segments_rep_distance_m_check;
alter table segments add constraint segments_rep_distance_m_check
  check (rep_distance_m is null or rep_distance_m > 0);

-- MARK: - 3. Private athlete data

create table if not exists athlete_private (
  user_id     uuid primary key references profiles on delete cascade,
  birth_date  date check (birth_date is null or birth_date >= '1900-01-01'),
  weight_kg   numeric(5, 1) check (weight_kg is null or weight_kg between 25 and 250),
  updated_at  timestamptz not null default now()
);

alter table athlete_private enable row level security;
drop policy if exists own_row on athlete_private;
create policy own_row on athlete_private for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
