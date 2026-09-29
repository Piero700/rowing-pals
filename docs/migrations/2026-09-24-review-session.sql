-- ---------------------------------------------------------------
-- Redesign phase F — review session
-- Run once per Supabase project, in the SQL editor, staging FIRST,
-- after the two 2026-09-23 migrations. One transaction: if anything
-- fails, nothing is applied.
--   * sessions.workout_label — the badge text on the main split:
--     'UT2', 'UT1', 'Threshold', 'Intervals', 'Test', 'Recovery', or a
--     test label such as '2k test'. Null on sessions posted before this.
--   * daily_totals.ranked_* — the volume the leaderboards read. Turning
--     off "Include on leaderboards" (and every manual entry) adds to the
--     personal distance columns and streak but not to these, so a session
--     can count for you without counting in the rankings.
--   * session_photos — the extra-photo strip (gallery photos beyond the
--     two dual-camera shots). Files live in the `monitors` bucket under
--     the owner's folder, so the existing storage policies already cover
--     them; this table just lists them in order.
-- ---------------------------------------------------------------
begin;

alter table sessions
  add column workout_label text
  check (workout_label is null or char_length(workout_label) between 1 and 24);

alter table daily_totals
  add column ranked_distance_m       int,
  add column ranked_erg_distance_m   int,
  add column ranked_water_distance_m int;

-- Everything logged so far was ranked.
update daily_totals
set ranked_distance_m       = distance_m,
    ranked_erg_distance_m   = erg_distance_m,
    ranked_water_distance_m = water_distance_m;

alter table daily_totals
  alter column ranked_distance_m       set not null,
  alter column ranked_distance_m       set default 0,
  alter column ranked_erg_distance_m   set not null,
  alter column ranked_erg_distance_m   set default 0,
  alter column ranked_water_distance_m set not null,
  alter column ranked_water_distance_m set default 0;

create table session_photos (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references sessions on delete cascade,
  position   int  not null,
  path       text not null,
  created_at timestamptz not null default now(),
  unique (session_id, position)
);

alter table session_photos enable row level security;

create policy read_visible on session_photos for select to authenticated
  using (can_view_session(session_id));

create policy own_via_session on session_photos for all to authenticated
  using (exists (
    select 1 from sessions s where s.id = session_photos.session_id and s.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from sessions s where s.id = session_photos.session_id and s.user_id = auth.uid()
  ));

commit;
