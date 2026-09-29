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
-- Post-level visibility (the `visibility` column on sessions) follows the
-- same approach for the same reason: FeedViewModel checks it against the
-- viewer's own club and follows. Separately (phase E), a *private account's*
-- data is enforced in RLS via can_view_user(), because hiding it in the client
-- alone would not stop anyone querying the API directly.

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
