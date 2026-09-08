-- Rowing Pals — initial schema
-- Run this in the Supabase SQL editor on your DEV project first.
-- Run it again, unchanged, on production when you get there.

-- ---------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------
create type session_type   as enum ('erg', 'water');
create type segment_label  as enum ('warmup', 'main', 'cooldown', 'extra');
create type rower_category as enum ('novice', 'senior');
create type rower_gender   as enum ('M', 'F');

-- ---------------------------------------------------------------
-- Clubs and people
-- ---------------------------------------------------------------
create table clubs (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  location    text,
  crest_path  text,
  created_at  timestamptz not null default now()
);

-- One row per user, keyed to Supabase's auth.users table.
create table profiles (
  id                     uuid primary key references auth.users on delete cascade,
  display_name           text not null,
  club_id                uuid references clubs on delete set null,
  gender                 rower_gender,
  category               rower_category not null default 'novice',
  avatar_path            text,
  weekly_target_sessions int not null default 4,
  created_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- Training
-- ---------------------------------------------------------------
create table sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references profiles on delete cascade,
  type             session_type not null,
  caption          text,

  -- Rolled up from segments. Kept on the row so the feed needs one query.
  total_distance_m int    not null,
  total_time_ms    bigint not null,
  avg_split_ms     int,             -- milliseconds per 500m
  avg_rate         numeric(4,1),    -- strokes per minute

  photo_verified   boolean not null default false,
  logged_late      boolean not null default false,

  captured_at      timestamptz not null,
  posted_at        timestamptz not null default now(),

  -- The user's LOCAL calendar day. Streaks and charts key off this, never UTC:
  -- a 06:00 row in London and a 23:00 row in Sydney must each land on their own day.
  session_date     date not null,

  created_at       timestamptz not null default now()
);

-- One segment per monitor photo. A session has one or more.
create table segments (
  id                 uuid primary key default gen_random_uuid(),
  session_id         uuid not null references sessions on delete cascade,
  label              segment_label not null default 'main',
  position           int not null,          -- display order within the session
  distance_m         int not null,
  time_ms            bigint not null,
  split_ms           int,
  rate               numeric(4,1),
  monitor_photo_path text,
  ocr_confidence     numeric(3,2),          -- 0.00–1.00, null for manual entry
  was_edited         boolean not null default false
);

-- A test result is created only when the user confirms the prompt.
create table test_results (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references profiles on delete cascade,
  session_id    uuid not null references sessions on delete cascade,
  segment_id    uuid not null references segments on delete cascade,

  distance_key  text not null,   -- '500m','1k','2k','5k','6k','10k','4min','30min','60min'
  distance_m    int not null,
  time_ms       bigint not null,
  split_ms      int not null,

  -- Snapshots, NOT joins to profiles. Category is self-declared and changeable,
  -- so reading it live would let one setting change silently rewrite history
  -- and empty the novice rankings.
  gender_at_time   rower_gender not null,
  category_at_time rower_category not null,

  set_at        timestamptz not null default now()
);

-- Pre-aggregated per day. Every profile chart and the streak read from here,
-- rather than each running its own scan over sessions.
create table daily_totals (
  user_id       uuid not null references profiles on delete cascade,
  day           date not null,
  distance_m    int not null default 0,
  session_count int not null default 0,
  primary key (user_id, day)
);

-- ---------------------------------------------------------------
-- Social
-- ---------------------------------------------------------------
create table follows (
  follower_id uuid not null references profiles on delete cascade,
  followee_id uuid not null references profiles on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create table reactions (
  session_id uuid not null references sessions on delete cascade,
  user_id    uuid not null references profiles on delete cascade,
  kind       text not null,   -- 'fire','grimace','clap','eyes'
  created_at timestamptz not null default now(),
  primary key (session_id, user_id, kind)
);

create table comments (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references sessions on delete cascade,
  user_id    uuid not null references profiles on delete cascade,
  body       text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- Moderation — App Store Guideline 1.2 requires these to exist.
-- Build them now, not after a rejection.
-- ---------------------------------------------------------------
create table blocks (
  blocker_id uuid not null references profiles on delete cascade,
  blocked_id uuid not null references profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

create table reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null references profiles on delete cascade,
  session_id   uuid references sessions on delete cascade,
  comment_id   uuid references comments on delete cascade,
  reason       text not null,
  status       text not null default 'open',  -- 'open','actioned','dismissed'
  created_at   timestamptz not null default now(),
  check (session_id is not null or comment_id is not null)
);

-- ---------------------------------------------------------------
-- Indexes — add these now; they are painful to notice you need later
-- ---------------------------------------------------------------
create index on sessions (posted_at desc);
create index on sessions (user_id, session_date desc);
create index on segments (session_id, position);
create index on comments (session_id, created_at);
create index on daily_totals (user_id, day desc);

-- The leaderboard index. Order matters: filters first, then the sort column.
create index on test_results (distance_key, gender_at_time, category_at_time, time_ms);

-- ---------------------------------------------------------------
-- Streak, with rest days
-- ---------------------------------------------------------------
-- Counts ACTIVE days, walking backwards from today. Two missed days per ISO
-- week are absorbed as rest and do not break the run; a third breaks it.
-- Today never breaks a streak, because the day is not over yet.
create or replace function current_streak(p_user uuid, p_today date)
returns table (active_days int, rest_used_this_week int)
language plpgsql stable as $$
declare
  d           date;
  wk          text;
  misses      jsonb := '{}'::jsonb;
  n           int := 0;
  wk_misses   int;
  has_session boolean;
begin
  d := p_today;

  select exists (
    select 1 from daily_totals t
    where t.user_id = p_user and t.day = d and t.session_count > 0
  ) into has_session;

  -- Nothing logged yet today? Start judging from yesterday.
  if not has_session then
    d := d - 1;
  end if;

  loop
    select exists (
      select 1 from daily_totals t
      where t.user_id = p_user and t.day = d and t.session_count > 0
    ) into has_session;

    wk        := to_char(d, 'IYYY-IW');          -- ISO week, so it resets Monday
    wk_misses := coalesce((misses ->> wk)::int, 0);

    if has_session then
      n := n + 1;
    else
      exit when wk_misses >= 2;                  -- rest allowance spent: streak ends
      misses := jsonb_set(misses, array[wk], to_jsonb(wk_misses + 1), true);
    end if;

    d := d - 1;
    exit when d < p_today - 730;                 -- safety bound
  end loop;

  return query
    select n, coalesce((misses ->> to_char(p_today, 'IYYY-IW'))::int, 0);
end $$;

-- ---------------------------------------------------------------
-- Row Level Security
-- Enable it on every table. A table without RLS in Supabase is readable
-- by anyone holding the anon key, which ships inside your app.
-- ---------------------------------------------------------------
alter table profiles     enable row level security;
alter table clubs        enable row level security;
alter table sessions     enable row level security;
alter table segments     enable row level security;
alter table test_results enable row level security;
alter table daily_totals enable row level security;
alter table follows      enable row level security;
alter table reactions    enable row level security;
alter table comments     enable row level security;
alter table blocks       enable row level security;
alter table reports      enable row level security;

-- Readable by any signed-in user.
create policy read_all on profiles     for select to authenticated using (true);
create policy read_all on clubs        for select to authenticated using (true);
create policy read_all on sessions     for select to authenticated using (true);
create policy read_all on segments     for select to authenticated using (true);
create policy read_all on test_results for select to authenticated using (true);
create policy read_all on daily_totals for select to authenticated using (true);
create policy read_all on follows      for select to authenticated using (true);
create policy read_all on reactions    for select to authenticated using (true);
create policy read_all on comments     for select to authenticated using (true);

-- Writable only by the person it belongs to.
create policy own_row on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy own_row on sessions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy own_row on test_results for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy own_row on reactions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy own_row on comments for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy own_row on follows for all to authenticated
  using (follower_id = auth.uid()) with check (follower_id = auth.uid());

-- Segments follow their session's owner.
create policy own_via_session on segments for all to authenticated
  using (exists (
    select 1 from sessions s where s.id = segments.session_id and s.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from sessions s where s.id = segments.session_id and s.user_id = auth.uid()
  ));

-- Blocks and reports are private to the person who made them.
create policy own_row on blocks for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

create policy own_row on reports for all to authenticated
  using (reporter_id = auth.uid()) with check (reporter_id = auth.uid());

-- NOTE: filtering blocked users out of the feed is done in a view or in the
-- query, not in RLS — keep the policies simple enough to reason about.
