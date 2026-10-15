-- Your bests (decision 64, user 2026-10-15). Run once in the Supabase SQL editor, staging
-- first. Safe to run again.
--
-- A rower can type in their current bests (2k, 5k, or any distance or time) at sign-up or in
-- Settings, so the Pace Engine has a starting point before they've logged an all-out piece.
-- The engine treats each one as an all-out piece rowed the day it was entered (never as
-- training), so it counts for 30 days, fading as their own pieces arrive. Not a test result:
-- it never appears on a leaderboard or as a PB.

begin;

create table if not exists declared_bests (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references profiles on delete cascade,
  distance_m  int not null check (distance_m between 100 and 100000),
  time_ms     bigint not null check (time_ms between 10000 and 36000000),
  -- The day it was entered (the rower's own calendar day): the engine dates it from here.
  set_on      date not null default current_date,
  created_at  timestamptz not null default now()
);
create index if not exists declared_bests_user on declared_bests (user_id);

alter table declared_bests enable row level security;

-- Your own: read, add, change, remove.
drop policy if exists own_row on declared_bests;
create policy own_row on declared_bests for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Your club's coaches read them, so the predictions they see match yours (decision 35).
drop policy if exists coach_read on declared_bests;
create policy coach_read on declared_bests for select to authenticated
  using (coaches_rower(user_id));

commit;
