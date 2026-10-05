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
-- Who can see a post, chosen at post time. No app-wide public option for
-- now — cancelled after the first round of testing, may return for a v2.
-- 'everyone' is the union of the other two (clubmates OR followers), not
-- every user of the app.
create type post_visibility as enum ('following', 'club', 'everyone');
-- Redesign phase E: a follow of a private account waits as 'pending'.
create type follow_status as enum ('pending', 'accepted');

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
  -- Metres target for the profile's weekly volume chart (task 15) - a
  -- separate figure from weekly_target_sessions, since a session count
  -- can't be plotted as a dashed line on a metres-scaled bar chart.
  weekly_target_m        int not null default 20000,
  -- Redesign phase E. A private account's data is visible only to its
  -- owner and approved followers; enforced by can_view_user() below.
  is_private             boolean not null default false,
  -- Set once, at signup, when the user agrees to the terms of service
  -- (task 17) - never updated after. Null means "never agreed", which
  -- shouldn't happen for any real account created after this column
  -- existed, but is distinguishable from a real timestamp on purpose.
  terms_accepted_at      timestamptz,
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
  visibility       post_visibility not null default 'everyone',
  -- Redesign phase F: the badge on the main split ('UT2', 'Threshold', '2k test'...).
  -- Decision 12: this session's test result beat the rower's previous best.
  is_new_pb        boolean not null default false,
  workout_label    text check (workout_label is null or char_length(workout_label) between 1 and 24),

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
  was_edited         boolean not null default false,
  -- Decision 10: the piece that leads the post on the feed. One per session.
  is_lead            boolean not null default false
);
create unique index segments_one_lead_per_session on segments (session_id) where is_lead;

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
-- rather than each running its own scan over sessions. erg/water columns
-- exist for the metres leaderboard's source split and toggle (task 13) -
-- distance_m is their sum, kept as its own maintained column since charts
-- elsewhere only ever need the combined total.
create table daily_totals (
  user_id          uuid not null references profiles on delete cascade,
  day              date not null,
  distance_m       int not null default 0,
  erg_distance_m   int not null default 0,
  water_distance_m int not null default 0,
  session_count    int not null default 0,
  -- Redesign phase F: what the leaderboards read. A session left off
  -- "Include on leaderboards", and every manual entry, adds to the personal
  -- columns above (profile, streak) but not to these.
  ranked_distance_m       int not null default 0,
  ranked_erg_distance_m   int not null default 0,
  ranked_water_distance_m int not null default 0,
  primary key (user_id, day)
);

-- Redesign phase F: the review screen's extra-photo strip. Files live in the
-- `monitors` bucket under the owner's folder; this lists them in order.
create table session_photos (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references sessions on delete cascade,
  position   int  not null,
  path       text not null,
  created_at timestamptz not null default now(),
  unique (session_id, position)
);

-- ---------------------------------------------------------------
-- Social
-- ---------------------------------------------------------------
create table follows (
  follower_id uuid not null references profiles on delete cascade,
  followee_id uuid not null references profiles on delete cascade,
  created_at  timestamptz not null default now(),
  -- Set by the follows_before_insert trigger, never by the client.
  status      follow_status not null default 'accepted',
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
alter table session_photos enable row level security;
alter table test_results enable row level security;
alter table daily_totals enable row level security;
alter table follows      enable row level security;
alter table reactions    enable row level security;
alter table comments     enable row level security;
alter table blocks       enable row level security;
alter table reports      enable row level security;

-- Who may see whose data (phase E). security definer so the helpers can read
-- profiles/follows unimpeded; auth.uid() is still the calling user.
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
    );
$$;

create or replace function can_view_session(sid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select can_view_user(s.user_id) from sessions s where s.id = sid), false);
$$;

-- Readable by any signed-in user (profiles and clubs). Everything a private
-- account owns is instead readable only per can_view_user(), defined above.
create policy read_all on profiles     for select to authenticated using (true);
create policy read_all on clubs        for select to authenticated using (true);
create policy read_visible on sessions for select to authenticated using (can_view_user(user_id));
create policy read_visible on segments for select to authenticated using (can_view_session(session_id));
create policy read_visible on session_photos for select to authenticated using (can_view_session(session_id));
create policy read_visible on test_results for select to authenticated using (can_view_user(user_id));
create policy read_visible on daily_totals for select to authenticated using (can_view_user(user_id));
-- follows read/insert/update/delete policies: see the phase E section at the end.
create policy read_visible on reactions for select to authenticated using (can_view_session(session_id));
create policy read_visible on comments for select to authenticated using (can_view_session(session_id));

-- Writable only by the person it belongs to.
-- Named differently from the update policy below — Postgres requires policy
-- names to be unique per table regardless of command, so reusing "own_row"
-- here would silently fail to create a second policy.
create policy insert_own on profiles for insert to authenticated
  with check (id = auth.uid());

create policy own_row on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy own_row on sessions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy own_row on test_results for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy own_row on reactions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy own_row on daily_totals for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy own_row on comments for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Segments follow their session's owner.
create policy own_via_session on segments for all to authenticated
  using (exists (
    select 1 from sessions s where s.id = segments.session_id and s.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from sessions s where s.id = segments.session_id and s.user_id = auth.uid()
  ));

create policy own_via_session on session_photos for all to authenticated
  using (exists (
    select 1 from sessions s where s.id = session_photos.session_id and s.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from sessions s where s.id = session_photos.session_id and s.user_id = auth.uid()
  ));

-- Reports are private to the person who made them.
create policy own_row on reports for all to authenticated
  using (reporter_id = auth.uid()) with check (reporter_id = auth.uid());

-- Blocks: both sides of a block can read it — the blocked party's own
-- client is the one that has to filter the blocker's posts out of *its*
-- feed (task 17), which needs it to know the block exists. Only the
-- blocker can create or remove the row.
create policy read_either_side on blocks for select to authenticated
  using (blocker_id = auth.uid() or blocked_id = auth.uid());
create policy write_own on blocks for insert to authenticated
  with check (blocker_id = auth.uid());
create policy delete_own on blocks for delete to authenticated
  using (blocker_id = auth.uid());

-- NOTE: filtering blocked users out of the feed is done in a view or in the
-- query, not in RLS — keep the policies simple enough to reason about.
-- Post-level visibility (the `visibility` column on sessions) is enforced in
-- RLS since decision 33: can_view_session() applies blocks, private accounts
-- and the post's own Following / Club / Everyone setting, and guards reading
-- posts, pieces, photos, comments and reactions, and adding comments and
-- reactions (see the 2026-10-05 post-visibility section at the end). The feed
-- still filters the same way in its query. A *private account's* other data
-- (test results, daily totals) is enforced via can_view_user().

-- ---------------------------------------------------------------
-- Redesign phase E — private accounts and follow requests
-- Canonical copy; an existing project gets it via
-- docs/migrations/2026-09-23-private-accounts.sql. The can_view_user() and
-- can_view_session() helpers it relies on are defined above the read
-- policies.
-- ---------------------------------------------------------------
-- follows: pending rows are seen only by the two people involved.
create policy read_follows on follows for select to authenticated
  using (
    follower_id = auth.uid()
    or followee_id = auth.uid()
    or (status = 'accepted' and (can_view_user(follower_id) or can_view_user(followee_id)))
  );

create policy follow_insert on follows for insert to authenticated
  with check (follower_id = auth.uid());

-- Only the person being followed may approve a request.
create policy follow_update on follows for update to authenticated
  using (followee_id = auth.uid()) with check (followee_id = auth.uid());

-- The follower can unfollow or cancel a request; the followee can
-- decline a request or remove a follower.
create policy follow_delete on follows for delete to authenticated
  using (follower_id = auth.uid() or followee_id = auth.uid());

-- The client can never choose its own status: a follow of a private
-- account is always 'pending', of a public account always 'accepted'.
create or replace function follows_set_status()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.status := case
    when coalesce((select p.is_private from profiles p where p.id = new.followee_id), false)
      then 'pending'::follow_status
    else 'accepted'::follow_status
  end;
  return new;
end $$;

create trigger follows_before_insert
  before insert on follows
  for each row execute function follows_set_status();

-- An approver may change only `status`, and only pending -> accepted.
-- Without this, the update policy would let a followee rewrite
-- follower_id and force other people to follow them.
create or replace function follows_guard_update()
returns trigger
language plpgsql as $$
begin
  if new.follower_id <> old.follower_id
     or new.followee_id <> old.followee_id
     or new.created_at <> old.created_at then
    raise exception 'only follows.status may be changed';
  end if;
  if old.status = 'accepted' and new.status = 'pending' then
    raise exception 'an accepted follow cannot go back to pending';
  end if;
  return new;
end $$;

create trigger follows_before_update
  before update on follows
  for each row execute function follows_guard_update();

-- Switching an account from private to public approves everything
-- waiting on it, as there is no longer anything to approve.
create or replace function profiles_privacy_changed()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.is_private and not new.is_private then
    update follows set status = 'accepted'
    where followee_id = new.id and status = 'pending';
  end if;
  return new;
end $$;

create trigger profiles_after_privacy_update
  after update of is_private on profiles
  for each row execute function profiles_privacy_changed();


-- ---------------------------------------------------------------
-- MANUAL STEP — photos (NOT part of the transaction above)
-- Photos live in the private buckets `monitors` and `selfies`, at
-- paths beginning `{user_id}/`. The database rules above do not cover
-- them: Storage has its own policies on storage.objects, which were set
-- in the dashboard and are not in this repo. Until they follow the same
-- rule, a private rower's photos can still be fetched by anyone who can
-- guess a path. In the dashboard: Storage > Policies. Delete any SELECT
-- policy on these two buckets that allows every signed-in user, then
-- run:
--
-- create policy read_visible_photos on storage.objects for select to authenticated
--   using (
--     bucket_id in ('monitors', 'selfies')
--     and can_view_user(((storage.foldername(name))[1])::uuid)
--   );
-- ---------------------------------------------------------------


-- ---------------------------------------------------------------
-- Push notifications (decision 19)
-- Canonical copy; an existing project gets it via
-- docs/migrations/2026-09-26-notifications.sql, plus the database
-- webhook on notifications INSERT -> send-push described in
-- docs/testing/notifications.md (webhooks are not SQL in this repo).
-- ---------------------------------------------------------------
-- One row per rower. A missing row means the defaults below.
create table if not exists notification_settings (
  user_id             uuid primary key references profiles on delete cascade,
  comments            boolean not null default true,
  personal_bests      boolean not null default true,
  club_activity       boolean not null default false,
  quiet_hours_enabled boolean not null default true,
  quiet_start         time not null default '22:00',
  quiet_end           time not null default '06:30',
  time_zone           text not null default 'Europe/London'
);
alter table notification_settings enable row level security;
drop policy if exists own_row on notification_settings;
create policy own_row on notification_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- One row per phone. No policies: only the functions below and the server read it.
create table if not exists device_tokens (
  token      text primary key,
  user_id    uuid not null references profiles on delete cascade,
  bundle_id  text not null,
  apns_env   text check (apns_env in ('sandbox', 'production')),
  updated_at timestamptz not null default now()
);
create index if not exists device_tokens_user_id_idx on device_tokens (user_id);
alter table device_tokens enable row level security;

-- The outbox. Triggers add rows; the send-push Edge Function delivers each one once.
create table if not exists notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles on delete cascade,
  actor_id     uuid not null references profiles on delete cascade,
  kind         text not null check (kind in ('comment', 'reply', 'pb', 'club_post')),
  session_id   uuid not null references sessions on delete cascade,
  comment_id   uuid references comments on delete cascade,
  created_at   timestamptz not null default now(),
  sent_at      timestamptz
);
create index if not exists notifications_recipient_idx on notifications (recipient_id, created_at desc);
create index if not exists notifications_session_idx on notifications (session_id);
alter table notifications enable row level security;
drop policy if exists read_own on notifications;
create policy read_own on notifications for select to authenticated
  using (recipient_id = auth.uid());

-- A phone signs in: its token now belongs to this rower, whoever had it before.
create or replace function register_device_token(p_token text, p_bundle_id text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  insert into device_tokens (token, user_id, bundle_id)
  values (p_token, auth.uid(), p_bundle_id)
  on conflict (token) do update
    set user_id = excluded.user_id,
        bundle_id = excluded.bundle_id,
        updated_at = now();
end $$;

-- A phone signs out: stop sending to it.
create or replace function unregister_device_token(p_token text)
returns void
language sql security definer set search_path = public as $$
  delete from device_tokens where token = p_token and user_id = auth.uid();
$$;

revoke all on function register_device_token(text, text) from public, anon;
revoke all on function unregister_device_token(text) from public, anon;
grant execute on function register_device_token(text, text) to authenticated;
grant execute on function unregister_device_token(text) to authenticated;

-- Whether a recipient may be told about a session. The same rules the feed applies:
-- no block either way, private accounts only to approved followers, and the
-- post's own audience (following / club / everyone = either).
create or replace function may_notify(recipient uuid, actor uuid, sid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from sessions s
    join profiles author on author.id = s.user_id
    left join profiles viewer on viewer.id = recipient
    where s.id = sid
      and not exists (
        select 1 from blocks b
        where (b.blocker_id = recipient and b.blocked_id in (actor, s.user_id))
           or (b.blocked_id = recipient and b.blocker_id in (actor, s.user_id))
      )
      and (
        s.user_id = recipient
        or (
          (not author.is_private or exists (
            select 1 from follows f
            where f.follower_id = recipient and f.followee_id = s.user_id and f.status = 'accepted'))
          and (
            (s.visibility in ('following', 'everyone') and exists (
              select 1 from follows f
              where f.follower_id = recipient and f.followee_id = s.user_id and f.status = 'accepted'))
            or (s.visibility in ('club', 'everyone')
                and author.club_id is not null and viewer.club_id = author.club_id)
          )
        )
      )
  );
$$;
revoke all on function may_notify(uuid, uuid, uuid) from public, anon, authenticated;

-- New comment: tell the post's owner, and everyone else who has commented on it.
create or replace function comments_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  owner uuid;
begin
  begin
    select s.user_id into owner from sessions s where s.id = new.session_id;
    if owner is null then
      return new;
    end if;
    insert into notifications (recipient_id, actor_id, kind, session_id, comment_id)
    select r.recipient, new.user_id, r.kind, new.session_id, new.id
    from (
      select owner as recipient, 'comment'::text as kind
      where owner <> new.user_id
      union
      select distinct c.user_id, 'reply'::text
      from comments c
      where c.session_id = new.session_id
        and c.id <> new.id
        and c.user_id <> new.user_id
        and c.user_id <> owner
    ) r
    left join notification_settings ns on ns.user_id = r.recipient
    where coalesce(ns.comments, true)
      and may_notify(r.recipient, new.user_id, new.session_id);
  exception when others then
    -- A notification problem must never stop a comment being posted.
    raise warning 'comments_notify: %', sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists comments_after_insert_notify on comments;
create trigger comments_after_insert_notify
  after insert on comments
  for each row execute function comments_notify();

-- New post. Fires on the post's first piece, not on the session row: the app saves
-- the pieces straight after the session, so by now the lead piece's numbers exist
-- for the alert text. Personal bests go to the rower and their followers; club
-- activity to clubmates (anyone already getting the PB alert is skipped).
create or replace function sessions_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  s sessions%rowtype;
  author_club uuid;
begin
  begin
    select * into s from sessions where id = new.session_id;
    if not found
       or s.posted_at < now() - interval '1 hour'
       or exists (select 1 from notifications n
                  where n.session_id = s.id and n.kind in ('pb', 'club_post')) then
      return new;
    end if;

    if s.is_new_pb then
      insert into notifications (recipient_id, actor_id, kind, session_id)
      select r.id, s.user_id, 'pb', s.id
      from (
        select s.user_id as id
        union
        select f.follower_id from follows f
        where f.followee_id = s.user_id and f.status = 'accepted'
      ) r
      left join notification_settings ns on ns.user_id = r.id
      where coalesce(ns.personal_bests, true)
        and may_notify(r.id, s.user_id, s.id);
    end if;

    select p.club_id into author_club from profiles p where p.id = s.user_id;
    if author_club is not null then
      insert into notifications (recipient_id, actor_id, kind, session_id)
      select p.id, s.user_id, 'club_post', s.id
      from profiles p
      left join notification_settings ns on ns.user_id = p.id
      where p.club_id = author_club
        and p.id <> s.user_id
        and coalesce(ns.club_activity, false)
        and may_notify(p.id, s.user_id, s.id)
        and not exists (select 1 from notifications n
                        where n.session_id = s.id and n.recipient_id = p.id and n.kind = 'pb');
    end if;
  exception when others then
    -- A notification problem must never stop a session being posted.
    raise warning 'sessions_notify: %', sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists segments_after_insert_notify on segments;
create trigger segments_after_insert_notify
  after insert on segments
  for each row when (new.position = 0)
  execute function sessions_notify();


-- ---------------------------------------------------------------
-- Onboarding without a club (decision 24)
-- Canonical copy; an existing project gets it via
-- docs/migrations/2026-09-29-onboarding.sql.
-- ---------------------------------------------------------------
alter table profiles add column if not exists onboarded_at timestamptz;

-- Everyone already in a club has finished onboarding.
update profiles
set onboarded_at = created_at
where club_id is not null and onboarded_at is null;


-- ---------------------------------------------------------------
-- Clubs (decision 25)
-- Canonical copy; an existing project gets it via
-- docs/migrations/2026-09-30-clubs.sql. The club directory is data, in
-- docs/migrations/2026-09-30-club-directory.sql.
-- ---------------------------------------------------------------
do $$ begin
  create type club_join_policy as enum ('open', 'approval', 'invite');
exception when duplicate_object then null; end $$;
do $$ begin
  create type club_role as enum ('member', 'admin', 'co_owner', 'owner');
exception when duplicate_object then null; end $$;

alter table clubs add column if not exists description text;
alter table clubs add column if not exists join_policy club_join_policy not null default 'open';
alter table clubs add column if not exists focus text not null default 'All rowing';
-- No created_by column: a second clubs↔profiles link would make every existing
-- `clubs(name)` lookup from profiles ambiguous. The owner is whoever has club_role 'owner'.
alter table clubs drop constraint if exists clubs_focus_check;
alter table clubs add constraint clubs_focus_check
  check (focus in ('All rowing', 'Indoor rowing', 'On-water rowing', 'University crew'));
alter table clubs drop constraint if exists clubs_text_lengths;
alter table clubs add constraint clubs_text_lengths
  check (char_length(name) between 1 and 60
         and (description is null or char_length(description) <= 400)
         and (location is null or char_length(location) <= 80));
create unique index if not exists clubs_name_unique on clubs (lower(name));

alter table profiles add column if not exists club_role club_role not null default 'member';

-- One pending request per rower: asking another club replaces it.
create table if not exists club_join_requests (
  user_id    uuid primary key references profiles on delete cascade,
  club_id    uuid not null references clubs on delete cascade,
  created_at timestamptz not null default now()
);
-- Its own id, and uniqueness by index rather than a (club_id, user_id) key: a key made of
-- both links would make PostgREST read this as a profiles↔clubs many-to-many route, and every
-- `clubs(name)` lookup from profiles would become ambiguous.
create table if not exists club_invites (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references clubs on delete cascade,
  user_id    uuid not null references profiles on delete cascade,
  invited_by uuid references profiles on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists club_invites_club_user on club_invites (club_id, user_id);
-- Kept out of `clubs`, which every rower can read.
create table if not exists club_invite_codes (
  club_id    uuid primary key references clubs on delete cascade,
  code       text not null unique,
  created_at timestamptz not null default now()
);
create index if not exists club_join_requests_club_idx on club_join_requests (club_id);
create index if not exists club_invites_user_idx on club_invites (user_id);

create or replace function club_rank(r club_role)
returns int
language sql immutable as $$
  select case r when 'member' then 0 when 'admin' then 1 when 'co_owner' then 2 else 3 end;
$$;

-- Whether the caller manages `p_club` at `p_min` or above.
create or replace function is_club_manager(p_club uuid, p_min club_role)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p
    where p.id = auth.uid() and p.club_id = p_club and club_rank(p.club_role) >= club_rank(p_min)
  );
$$;

alter table club_join_requests enable row level security;
alter table club_invites enable row level security;
alter table club_invite_codes enable row level security;
drop policy if exists read_own_or_managed on club_join_requests;
create policy read_own_or_managed on club_join_requests for select to authenticated
  using (user_id = auth.uid() or is_club_manager(club_id, 'admin'));
drop policy if exists read_own_or_managed on club_invites;
create policy read_own_or_managed on club_invites for select to authenticated
  using (user_id = auth.uid() or is_club_manager(club_id, 'admin'));
drop policy if exists read_managed on club_invite_codes;
create policy read_managed on club_invite_codes for select to authenticated
  using (is_club_manager(club_id, 'admin'));

-- The guard. The functions below switch it off for their own transaction only.
create or replace function profiles_guard_club()
returns trigger
language plpgsql as $$
begin
  if coalesce(current_setting('rp.club_change', true), '') = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.club_id is not null or new.club_role <> 'member' then
      raise exception 'Join a club from the app';
    end if;
  elsif new.club_id is distinct from old.club_id or new.club_role is distinct from old.club_role then
    raise exception 'Club membership changes go through the app';
  end if;
  return new;
end $$;
drop trigger if exists profiles_guard_club on profiles;
create trigger profiles_guard_club
  before insert or update on profiles
  for each row execute function profiles_guard_club();

-- MARK: - Joining and leaving

-- Owners must hand over or delete their club first, or it would be left without one.
create or replace function club_assert_not_owner()
returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if exists (select 1 from profiles where id = auth.uid() and club_id is not null and club_role = 'owner') then
    raise exception 'You own your club. Hand it over to another member or delete it first.';
  end if;
end $$;

create or replace function club_set_membership(p_user uuid, p_club uuid, p_role club_role)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('rp.club_change', 'on', true);
  update profiles set club_id = p_club, club_role = p_role where id = p_user;
  if p_club is not null then
    delete from club_join_requests where user_id = p_user;
    delete from club_invites where user_id = p_user and club_id = p_club;
  end if;
end $$;

-- 'joined' (open club, or you were invited), 'requested' (approval club), 'invite_only'.
create or replace function join_club(p_club uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_policy club_join_policy;
  v_current uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select join_policy into v_policy from clubs where id = p_club;
  if not found then raise exception 'That club no longer exists.'; end if;
  select club_id into v_current from profiles where id = auth.uid();
  if v_current = p_club then return 'joined'; end if;
  perform club_assert_not_owner();
  if v_policy = 'open' or exists (select 1 from club_invites where club_id = p_club and user_id = auth.uid()) then
    perform club_set_membership(auth.uid(), p_club, 'member');
    return 'joined';
  elsif v_policy = 'approval' then
    insert into club_join_requests (user_id, club_id) values (auth.uid(), p_club)
    on conflict (user_id) do update set club_id = excluded.club_id, created_at = now();
    return 'requested';
  end if;
  return 'invite_only';
end $$;

create or replace function join_club_with_code(p_code text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select club_id into v_club from club_invite_codes where code = upper(trim(p_code));
  if v_club is null then raise exception 'That invite code isn''t right. Check it with the club.'; end if;
  if exists (select 1 from profiles where id = auth.uid() and club_id = v_club) then return v_club; end if;
  perform club_assert_not_owner();
  perform club_set_membership(auth.uid(), v_club, 'member');
  return v_club;
end $$;

create or replace function leave_club()
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform club_assert_not_owner();
  perform club_set_membership(auth.uid(), null, 'member');
end $$;

create or replace function cancel_join_request()
returns void
language sql security definer set search_path = public as $$
  delete from club_join_requests where user_id = auth.uid();
$$;

create or replace function respond_club_invite(p_club uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from club_invites where club_id = p_club and user_id = auth.uid()) then
    raise exception 'That invitation has been withdrawn.';
  end if;
  if p_accept then
    perform club_assert_not_owner();
    perform club_set_membership(auth.uid(), p_club, 'member');
  else
    delete from club_invites where club_id = p_club and user_id = auth.uid();
  end if;
end $$;

-- MARK: - Creating and editing

create or replace function create_club(p_name text, p_description text, p_location text, p_policy club_join_policy, p_focus text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  perform club_assert_not_owner();
  begin
    insert into clubs (name, description, location, join_policy, focus)
    values (trim(p_name), nullif(trim(p_description), ''), nullif(trim(p_location), ''), p_policy, p_focus)
    returning id into v_club;
  exception when unique_violation then
    raise exception 'A club with that name already exists. Find it and ask to join.';
  end;
  perform club_set_membership(auth.uid(), v_club, 'owner');
  return v_club;
end $$;

create or replace function update_club(p_name text, p_description text, p_location text, p_policy club_join_policy, p_focus text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'co_owner') then
    raise exception 'Only the owner and co-owners can edit the club.';
  end if;
  begin
    update clubs
    set name = trim(p_name), description = nullif(trim(p_description), ''),
        location = nullif(trim(p_location), ''), join_policy = p_policy, focus = p_focus
    where id = v_club;
  exception when unique_violation then
    raise exception 'Another club already has that name.';
  end;
end $$;

-- MARK: - Managing members (admins and up)

create or replace function respond_join_request(p_user uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from club_join_requests where user_id = p_user;
  if v_club is null then raise exception 'That request has been withdrawn.'; end if;
  if not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can answer requests.';
  end if;
  if p_accept then
    if exists (select 1 from profiles where id = p_user and club_id is not null and club_role = 'owner') then
      raise exception 'They own another club, so they can''t join until they hand it over.';
    end if;
    perform club_set_membership(p_user, v_club, 'member');
  else
    delete from club_join_requests where user_id = p_user;
  end if;
end $$;

create or replace function invite_rower(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can invite rowers.';
  end if;
  if exists (select 1 from profiles where id = p_user and club_id = v_club) then
    raise exception 'They''re already in the club.';
  end if;
  insert into club_invites (club_id, user_id, invited_by) values (v_club, p_user, auth.uid())
  on conflict do nothing;
end $$;

create or replace function withdraw_club_invite(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can withdraw invitations.';
  end if;
  delete from club_invites where club_id = v_club and user_id = p_user;
end $$;

-- The club's invite code, made on first request. Admins and up.
create or replace function club_invite_code(p_new boolean default false)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_code text;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can share the invite code.';
  end if;
  select code into v_code from club_invite_codes where club_id = v_club;
  if v_code is null or p_new then
    loop
      v_code := upper(substr(md5(gen_random_uuid()::text), 1, 8));
      begin
        insert into club_invite_codes (club_id, code) values (v_club, v_code)
        on conflict (club_id) do update set code = excluded.code, created_at = now();
        exit;
      exception when unique_violation then
        -- Another club already has this code; try another.
      end;
    end loop;
  end if;
  return v_code;
end $$;

-- Roles: co-owners and the owner change them; only the owner makes or unmakes co-owners.
-- Nobody changes the role of someone at or above their own.
create or replace function set_club_role(p_user uuid, p_role club_role)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_mine club_role;
  v_theirs club_role;
begin
  if p_role = 'owner' then raise exception 'Use Hand over ownership instead.'; end if;
  select club_id, club_role into v_club, v_mine from profiles where id = auth.uid();
  select club_role into v_theirs from profiles where id = p_user and club_id = v_club;
  if v_club is null or v_theirs is null or p_user = auth.uid() then
    raise exception 'They''re not in your club.';
  end if;
  if club_rank(v_mine) < club_rank('co_owner')
     or club_rank(v_theirs) >= club_rank(v_mine)
     or (p_role = 'co_owner' and v_mine <> 'owner') then
    raise exception 'You can''t change that role.';
  end if;
  perform club_set_membership(p_user, v_club, p_role);
end $$;

-- Admins remove members; co-owners also admins; the owner anyone.
create or replace function remove_club_member(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_mine club_role;
  v_theirs club_role;
begin
  select club_id, club_role into v_club, v_mine from profiles where id = auth.uid();
  select club_role into v_theirs from profiles where id = p_user and club_id = v_club;
  if v_club is null or v_theirs is null or p_user = auth.uid() then
    raise exception 'They''re not in your club.';
  end if;
  if club_rank(v_mine) < club_rank('admin') or club_rank(v_theirs) >= club_rank(v_mine) then
    raise exception 'You can''t remove them.';
  end if;
  perform club_set_membership(p_user, null, 'member');
end $$;

-- MARK: - Ownership

-- The new owner takes over; the old owner stays on as a co-owner.
create or replace function transfer_club_ownership(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid() and club_role = 'owner';
  if v_club is null then raise exception 'Only the owner can hand over the club.'; end if;
  if not exists (select 1 from profiles where id = p_user and club_id = v_club) or p_user = auth.uid() then
    raise exception 'They''re not in your club.';
  end if;
  perform club_set_membership(p_user, v_club, 'owner');
  perform club_set_membership(auth.uid(), v_club, 'co_owner');
end $$;

-- Everyone in it is left without a club; their sessions, metres and PBs stay theirs.
create or replace function delete_club()
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid() and club_role = 'owner';
  if v_club is null then raise exception 'Only the owner can delete the club.'; end if;
  perform set_config('rp.club_change', 'on', true);
  update profiles set club_id = null, club_role = 'member' where club_id = v_club;
  delete from clubs where id = v_club;
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'join_club(uuid)', 'join_club_with_code(text)', 'leave_club()', 'cancel_join_request()',
    'respond_club_invite(uuid, boolean)',
    'create_club(text, text, text, club_join_policy, text)',
    'update_club(text, text, text, club_join_policy, text)',
    'respond_join_request(uuid, boolean)', 'invite_rower(uuid)', 'withdraw_club_invite(uuid)',
    'club_invite_code(boolean)', 'set_club_role(uuid, club_role)', 'remove_club_member(uuid)',
    'transfer_club_ownership(uuid)', 'delete_club()'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array['club_assert_not_owner()', 'club_set_membership(uuid, uuid, club_role)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $$;


-- ---------------------------------------------------------------
-- Club follow-ups (decision 26)
-- Canonical copy; an existing project gets it via
-- docs/migrations/2026-10-04-club-updates.sql.
-- ---------------------------------------------------------------
-- MARK: - 1. Remembering "declined"

alter table club_join_requests add column if not exists status text not null default 'pending';
alter table club_join_requests add column if not exists responded_at timestamptz;
alter table club_join_requests drop constraint if exists club_join_requests_status_check;
alter table club_join_requests add constraint club_join_requests_status_check
  check (status in ('pending', 'declined'));

alter table club_invites add column if not exists status text not null default 'pending';
alter table club_invites add column if not exists responded_at timestamptz;
alter table club_invites drop constraint if exists club_invites_status_check;
alter table club_invites add constraint club_invites_status_check
  check (status in ('pending', 'declined'));

-- Asking again — the same club or another — replaces a declined (or pending) request.
create or replace function join_club(p_club uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_policy club_join_policy;
  v_current uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select join_policy into v_policy from clubs where id = p_club;
  if not found then raise exception 'That club no longer exists.'; end if;
  select club_id into v_current from profiles where id = auth.uid();
  if v_current = p_club then return 'joined'; end if;
  perform club_assert_not_owner();
  if v_policy = 'open' or exists (
    select 1 from club_invites where club_id = p_club and user_id = auth.uid() and status = 'pending'
  ) then
    perform club_set_membership(auth.uid(), p_club, 'member');
    return 'joined';
  elsif v_policy = 'approval' then
    insert into club_join_requests (user_id, club_id) values (auth.uid(), p_club)
    on conflict (user_id) do update
      set club_id = excluded.club_id, status = 'pending', created_at = now(), responded_at = null;
    return 'requested';
  end if;
  return 'invite_only';
end $$;

-- Declining keeps the invitation, marked declined, so the club can see the answer.
create or replace function respond_club_invite(p_club uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from club_invites where club_id = p_club and user_id = auth.uid() and status = 'pending'
  ) then
    raise exception 'That invitation has been withdrawn.';
  end if;
  if p_accept then
    perform club_assert_not_owner();
    perform club_set_membership(auth.uid(), p_club, 'member');
  else
    update club_invites set status = 'declined', responded_at = now()
    where club_id = p_club and user_id = auth.uid();
  end if;
end $$;

-- Declining keeps the request, marked declined, so the rower who asked is told.
create or replace function respond_join_request(p_user uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from club_join_requests where user_id = p_user and status = 'pending';
  if v_club is null then raise exception 'That request has been withdrawn.'; end if;
  if not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can answer requests.';
  end if;
  if p_accept then
    if exists (select 1 from profiles where id = p_user and club_id is not null and club_role = 'owner') then
      raise exception 'They own another club, so they can''t join until they hand it over.';
    end if;
    perform club_set_membership(p_user, v_club, 'member');
  else
    update club_join_requests set status = 'declined', responded_at = now() where user_id = p_user;
  end if;
end $$;

-- Inviting again (after a decline) re-sends it.
create or replace function invite_rower(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only admins, co-owners and the owner can invite rowers.';
  end if;
  if exists (select 1 from profiles where id = p_user and club_id = v_club) then
    raise exception 'They''re already in the club.';
  end if;
  insert into club_invites (club_id, user_id, invited_by) values (v_club, p_user, auth.uid())
  on conflict (club_id, user_id) do update
    set status = 'pending', invited_by = excluded.invited_by, created_at = now(), responded_at = null;
end $$;

-- MARK: - 2. Invitation alerts

do $$
begin
  if to_regclass('public.notifications') is null then
    raise notice 'No notifications table: run 2026-09-26-notifications.sql, then this file again, for invitation alerts.';
    return;
  end if;
  alter table notifications alter column session_id drop not null;
  alter table notifications add column if not exists club_id uuid references clubs on delete cascade;
  alter table notifications drop constraint if exists notifications_kind_check;
  alter table notifications add constraint notifications_kind_check
    check (kind in ('comment', 'reply', 'pb', 'club_post', 'club_invite'));
end $$;

-- A new (or re-sent) invitation: tell the invited rower, unless either has blocked the other.
create or replace function club_invites_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.status = 'pending'
       and (tg_op = 'INSERT' or old.status <> 'pending' or old.created_at <> new.created_at)
       and not exists (
         select 1 from blocks b
         where (b.blocker_id = new.user_id and b.blocked_id = new.invited_by)
            or (b.blocker_id = new.invited_by and b.blocked_id = new.user_id)
       ) then
      insert into notifications (recipient_id, actor_id, kind, club_id)
      values (new.user_id, coalesce(new.invited_by, new.user_id), 'club_invite', new.club_id);
    end if;
  exception when others then
    -- An alert problem must never stop an invitation being sent.
    raise warning 'club_invites_notify: %', sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists club_invites_after_write_notify on club_invites;
create trigger club_invites_after_write_notify
  after insert or update on club_invites
  for each row execute function club_invites_notify();

-- MARK: - 3. Live updates

do $$
declare
  t text;
begin
  foreach t in array array['profiles', 'clubs', 'club_join_requests', 'club_invites'] loop
    begin
      execute format('alter publication supabase_realtime add table %I', t);
    exception
      when duplicate_object then null;
      when undefined_object then raise notice 'No supabase_realtime publication; live updates are off.';
    end;
  end loop;
end $$;

-- =====================================================================
-- docs/migrations/2026-10-04-club-tests.sql (decision 28)
-- =====================================================================

-- Club tests (decision 28). Run once in the Supabase SQL editor, staging first, after
-- docs/migrations/2026-09-30-clubs.sql. Safe to run again.
--
-- A club's admins and up add their own tests — a distance (750m, 3k) or a whole number of
-- minutes (20min) — next to the nine standard ones. Every member sees them under Rankings →
-- Test results and can post a result to them, which goes on that test's leaderboard.
--
-- Results live in `test_results` like any other, with `distance_key` = 'club:<test id>'. Every
-- other reader (profile PBs, club rankings) only looks for the nine standard keys, so a club
-- result never shows up there. The database checks each club result: the test exists, the
-- rower is in that club, and the piece is the test's distance (or its time, within the same
-- small finish-line tolerance the app allows).

-- MARK: - Table

create table if not exists club_tests (
  id          uuid primary key default gen_random_uuid(),
  -- The only link to another table: a second clubs↔profiles route would make every
  -- `clubs(name)` embed from profiles ambiguous.
  club_id     uuid not null references clubs on delete cascade,
  label       text not null,
  distance_m  int check (distance_m between 100 and 100000),
  duration_ms int check (duration_ms between 60000 and 7200000 and duration_ms % 60000 = 0),
  created_at  timestamptz not null default now(),
  constraint club_tests_one_target check ((distance_m is null) <> (duration_ms is null))
);
create unique index if not exists club_tests_unique_label on club_tests (club_id, lower(label));

alter table club_tests enable row level security;
-- A test's name and target aren't private; a follower reading a clubmate's post sees it too.
-- No write policies: tests change only through the functions below.
drop policy if exists read_all on club_tests;
create policy read_all on club_tests for select to authenticated using (true);

-- MARK: - Naming

-- "750m", "3k", "20min" — the same style as the standard tests' tiles. The app shows the
-- same rule while the admin types (`ClubTest.label`).
create or replace function club_test_label(p_distance_m int, p_duration_ms int)
returns text
language sql immutable as $$
  select case
    when p_distance_m is not null then
      case when p_distance_m % 1000 = 0 then (p_distance_m / 1000)::text || 'k'
           else p_distance_m::text || 'm' end
    else (p_duration_ms / 60000)::text || 'min'
  end;
$$;

-- MARK: - Adding and deleting (admins and up)

create or replace function create_club_test(p_distance_m int, p_duration_ms int)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_label text;
  v_id uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only club admins and up can add a test.';
  end if;
  if (p_distance_m is null) = (p_duration_ms is null) then
    raise exception 'Choose a distance or a time.';
  end if;
  if p_distance_m is not null and p_distance_m not between 100 and 100000 then
    raise exception 'A distance test must be between 100m and 100,000m.';
  end if;
  if p_duration_ms is not null
     and (p_duration_ms % 60000 <> 0 or p_duration_ms not between 60000 and 7200000) then
    raise exception 'A timed test must be a whole number of minutes, from 1 to 120.';
  end if;
  if p_distance_m in (500, 1000, 2000, 5000, 6000, 10000)
     or p_duration_ms in (4 * 60000, 30 * 60000, 60 * 60000) then
    raise exception 'That''s already a standard test.';
  end if;

  v_label := club_test_label(p_distance_m, p_duration_ms);
  begin
    insert into club_tests (club_id, label, distance_m, duration_ms)
    values (v_club, v_label, p_distance_m, p_duration_ms)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'Your club already has a % test.', v_label;
  end;
  return v_id;
end $$;

create or replace function delete_club_test(p_test uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from club_tests where id = p_test;
  if v_club is null then raise exception 'That test no longer exists.'; end if;
  if not is_club_manager(v_club, 'admin') then
    raise exception 'Only club admins and up can delete a test.';
  end if;
  delete from club_tests where id = p_test;
end $$;

-- A deleted test takes its results with it — whether deleted on its own or with its club.
create or replace function club_tests_delete_results()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from test_results where distance_key = 'club:' || old.id;
  return old;
end $$;

drop trigger if exists club_tests_delete_results on club_tests;
create trigger club_tests_delete_results after delete on club_tests
  for each row execute function club_tests_delete_results();

-- MARK: - Checking each club result

create or replace function test_results_check_club_test()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_test club_tests%rowtype;
begin
  if new.distance_key not like 'club:%' then return new; end if;

  begin
    select * into v_test from club_tests where id = substring(new.distance_key from 6)::uuid;
  exception when invalid_text_representation then
    raise exception 'Unknown club test.';
  end;
  if not found then raise exception 'Unknown club test.'; end if;

  if not exists (select 1 from profiles where id = new.user_id and club_id = v_test.club_id) then
    raise exception 'Only members of the club can post to its tests.';
  end if;
  if v_test.distance_m is not null and new.distance_m <> v_test.distance_m then
    raise exception 'A % test must be exactly %m.', v_test.label, v_test.distance_m;
  end if;
  if v_test.duration_ms is not null
     and abs(new.time_ms - v_test.duration_ms) > greatest(2000, v_test.duration_ms / 100) then
    raise exception 'A % test must be % long.', v_test.label, v_test.label;
  end if;
  return new;
end $$;

drop trigger if exists test_results_check_club_test on test_results;
create trigger test_results_check_club_test before insert or update on test_results
  for each row execute function test_results_check_club_test();

-- MARK: - Permissions

revoke all on function create_club_test(int, int) from public, anon;
grant execute on function create_club_test(int, int) to authenticated;
revoke all on function delete_club_test(uuid) from public, anon;
grant execute on function delete_club_test(uuid) to authenticated;

-- =====================================================================
-- docs/migrations/2026-10-05-seconds-tests-and-avatars.sql (decisions 28, 29)
-- =====================================================================

-- Seconds tests and profile pictures (decisions 28 and 29). Run once in the Supabase SQL editor,
-- staging first, after docs/migrations/2026-10-04-club-tests.sql. Safe to run again.
--
-- 1. A club test can be a time in seconds (30s, 90s), not only whole minutes. A time that is a
--    whole number of minutes is still named in minutes, so 120 seconds and 2min are one test.
--    Short tests get a tighter finish tolerance: 2 s or 1%, whichever is bigger, but at most 5%
--    of the test (1.5 s on a 30s test). Every test of 40 s and up is unchanged.
-- 2. Profile pictures live in a new private `avatars` bucket at <user id>/<file>.jpg, the path
--    kept in `profiles.avatar_path` (already a column). A rower can only write their own
--    folder; a picture is seen under the same rule as workout photos (`can_view_user`), so a
--    private account's picture shows only to its approved followers.

-- MARK: - 1. Seconds tests

alter table club_tests drop constraint if exists club_tests_duration_ms_check;
alter table club_tests add constraint club_tests_duration_ms_check
  check (duration_ms between 10000 and 7200000 and duration_ms % 1000 = 0);

create or replace function club_test_label(p_distance_m int, p_duration_ms int)
returns text
language sql immutable as $$
  select case
    when p_distance_m is not null then
      case when p_distance_m % 1000 = 0 then (p_distance_m / 1000)::text || 'k'
           else p_distance_m::text || 'm' end
    when p_duration_ms % 60000 = 0 then (p_duration_ms / 60000)::text || 'min'
    else (p_duration_ms / 1000)::text || 's'
  end;
$$;

create or replace function create_club_test(p_distance_m int, p_duration_ms int)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_label text;
  v_id uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only club admins and up can add a test.';
  end if;
  if (p_distance_m is null) = (p_duration_ms is null) then
    raise exception 'Choose a distance or a time.';
  end if;
  if p_distance_m is not null and p_distance_m not between 100 and 100000 then
    raise exception 'A distance test must be between 100m and 100,000m.';
  end if;
  if p_duration_ms is not null
     and (p_duration_ms % 1000 <> 0 or p_duration_ms not between 10000 and 7200000) then
    raise exception 'A timed test must be from 10 seconds to 120 minutes.';
  end if;
  if p_distance_m in (500, 1000, 2000, 5000, 6000, 10000)
     or p_duration_ms in (4 * 60000, 30 * 60000, 60 * 60000) then
    raise exception 'That''s already a standard test.';
  end if;

  v_label := club_test_label(p_distance_m, p_duration_ms);
  begin
    insert into club_tests (club_id, label, distance_m, duration_ms)
    values (v_club, v_label, p_distance_m, p_duration_ms)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'Your club already has a % test.', v_label;
  end;
  return v_id;
end $$;

create or replace function test_results_check_club_test()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_test club_tests%rowtype;
begin
  if new.distance_key not like 'club:%' then return new; end if;

  begin
    select * into v_test from club_tests where id = substring(new.distance_key from 6)::uuid;
  exception when invalid_text_representation then
    raise exception 'Unknown club test.';
  end;
  if not found then raise exception 'Unknown club test.'; end if;

  if not exists (select 1 from profiles where id = new.user_id and club_id = v_test.club_id) then
    raise exception 'Only members of the club can post to its tests.';
  end if;
  if v_test.distance_m is not null and new.distance_m <> v_test.distance_m then
    raise exception 'A % test must be exactly %m.', v_test.label, v_test.distance_m;
  end if;
  -- Same rule as the app's StandardTest.finishTolerance.
  if v_test.duration_ms is not null
     and abs(new.time_ms - v_test.duration_ms)
         > greatest(least(2000, v_test.duration_ms / 20), v_test.duration_ms / 100) then
    raise exception 'A % test must be % long.', v_test.label, v_test.label;
  end if;
  return new;
end $$;

revoke all on function create_club_test(int, int) from public, anon;
grant execute on function create_club_test(int, int) to authenticated;

-- MARK: - 2. Profile pictures

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

drop policy if exists avatars_read_visible on storage.objects;
create policy avatars_read_visible on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and can_view_user(((storage.foldername(name))[1])::uuid));

drop policy if exists avatars_own_folder_insert on storage.objects;
create policy avatars_own_folder_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_own_folder_delete on storage.objects;
create policy avatars_own_folder_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- =====================================================================
-- docs/migrations/2026-10-05-pace-engine-inputs.sql (decisions 30, 31)
-- =====================================================================

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


-- ---------------------------------------------------------------
-- Who can see a post, and who can comment (decision 33). Canonical copy of
-- docs/migrations/2026-10-05-post-visibility.sql; it replaces can_view_session(),
-- the sessions read policy and the photo read policy defined earlier in this file.
-- ---------------------------------------------------------------

-- Who can see a post, and who can comment on it (decision 33). Run once in the Supabase SQL
-- editor, staging first. Safe to run again. One transaction: no policy is ever dropped
-- without its replacement.
--
-- The rule, the same one the feed and notifications already use: you can see a post if it's
-- yours, or —
--   * neither of you has blocked the other, and
--   * the author's account is public, or you're their approved follower, and
--   * the post's own setting lets you in:
--       "Following" → you follow the author (accepted);
--       "Club"      → you're in the author's club;
--       "Everyone"  → either.
-- If you can see a post, you can comment on it and react to it.
--
-- Before this, the database only applied the private-account part: any signed-in rower could
-- read every public rower's posts (the app just never asked), and could comment on or react
-- to any post at all. Now the database enforces the whole rule:
--   * reading posts, their pieces, extra photos, comments and reactions;
--   * reading the monitor photos, gallery photos and selfies in storage;
--   * adding a comment or a reaction.
-- Not changed: test results and daily totals (rankings and profile stats, which already follow
-- the private-account rule), avatars, and everything you do with your own rows.

begin;

-- MARK: - The rule

-- Replaces the phase E version, which only checked the author's private-account setting.
-- Every policy that already used it (pieces, extra photos, comments, reactions) picks up the
-- full rule from here.
create or replace function can_view_session(sid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select s.user_id = auth.uid()
      or (
        not exists (
          select 1 from blocks b
          where (b.blocker_id = auth.uid() and b.blocked_id = s.user_id)
             or (b.blocker_id = s.user_id and b.blocked_id = auth.uid())
        )
        and (
          not author.is_private
          or exists (
            select 1 from follows f
            where f.follower_id = auth.uid() and f.followee_id = s.user_id and f.status = 'accepted'
          )
        )
        and (
          (s.visibility in ('following', 'everyone') and exists (
            select 1 from follows f
            where f.follower_id = auth.uid() and f.followee_id = s.user_id and f.status = 'accepted'
          ))
          or (s.visibility in ('club', 'everyone')
              and author.club_id is not null
              and author.club_id = (select viewer.club_id from profiles viewer where viewer.id = auth.uid()))
        )
      )
    from sessions s
    join profiles author on author.id = s.user_id
    where s.id = sid
  ), false);
$$;

-- The session a photo belongs to, from its storage path:
--   monitors  <user>/<session>/<position>.jpg  and  <user>/<session>/gallery-<n>.jpg
--   selfies   <user>/<session>.jpg
-- Null for any other shape, which then falls back to "owner only".
create or replace function photo_session_id(object_name text)
returns uuid
language sql stable set search_path = public as $$
  select case
    when array_length(storage.foldername(object_name), 1) >= 2
         and (storage.foldername(object_name))[2] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(object_name))[2])::uuid
    when array_length(storage.foldername(object_name), 1) = 1
         and split_part(storage.filename(object_name), '.', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then (split_part(storage.filename(object_name), '.', 1))::uuid
  end;
$$;

-- MARK: - Reading

-- Posts themselves (was: the author's account is visible). Your own stay readable through
-- the existing own_row policy.
drop policy if exists read_visible on sessions;
create policy read_visible on sessions for select to authenticated
  using (can_view_session(id));

-- Pieces, extra photos, comments and reactions already read through can_view_session().

-- Photos (was: the owner's account is visible). Your own folder stays readable — a photo is
-- uploaded before its post exists.
drop policy if exists read_visible_photos on storage.objects;
create policy read_visible_photos on storage.objects
  for select to authenticated
  using (
    bucket_id in ('monitors', 'selfies')
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or can_view_session(photo_session_id(name))
    )
  );

-- MARK: - Writing

-- Restrictive: added on top of own_row ("only in your own name"), so both must hold.
drop policy if exists comment_on_visible on comments;
create policy comment_on_visible on comments as restrictive
  for insert to authenticated
  with check (can_view_session(session_id));

drop policy if exists react_on_visible on reactions;
create policy react_on_visible on reactions as restrictive
  for insert to authenticated
  with check (can_view_session(session_id));

commit;
