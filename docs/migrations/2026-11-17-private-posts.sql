-- Private posts (decision 106, user 2026-11-17). Run once in the Supabase SQL editor, staging
-- first, BEFORE installing the build that needs it (the app reads sessions.is_private). Safe to
-- run again.
--
-- A rower can make a post they've already put up private, one at a time, and visible again.
-- While a post is private:
--   * only its owner can read it — not followers, clubmates, or a coach of their club (the user
--     chose "hidden from coach too"), so it leaves the Feed, other people's view of the profile,
--     a coach's set-workout results and the rower pages coaches open;
--   * its test result is off the test leaderboards and others' PB tiles and club ranks, and its
--     metres are off the volume leaderboards, challenges, weekly rank alerts and Season Wrapped's
--     club comparisons (daily_totals.ranked_* lose them, and get them back when it's visible);
--   * it's off an erg event's board;
--   * the owner still counts it everywhere that's theirs alone: own totals, streak, PBs and
--     predictions.
-- Making a post private also removes other people's notifications about it, so nobody is left
-- holding a link to a post they can't open. Making it visible again doesn't bring them back.

begin;

-- MARK: - 1. The flag

alter table sessions add column if not exists is_private boolean not null default false;

-- Only set_session_private() changes it, so the leaderboard totals always move with it. A new
-- post is never private (it goes up visible; the owner makes it private afterwards).
create or replace function sessions_guard_private()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.is_private := false;
  elsif new.is_private is distinct from old.is_private
        and coalesce(current_setting('rp.private_change', true), '') <> 'on' then
    new.is_private := old.is_private;
  end if;
  return new;
end $$;

drop trigger if exists sessions_guard_private on sessions;
create trigger sessions_guard_private
  before insert or update of is_private on sessions
  for each row execute function sessions_guard_private();

-- MARK: - 2. Who can read a private post: its owner only

-- As 2026-11-03-mutual-follow-posts.sql, with "and not s.is_private" for everyone but the owner.
-- This also stops others reacting to or commenting on it (the restrictive insert policies).
create or replace function can_view_session(sid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select s.user_id = auth.uid()
      or (
        not s.is_private
        and not exists (
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
          (s.visibility in ('following', 'everyone')
           and exists (
             select 1 from follows f
             where f.follower_id = auth.uid() and f.followee_id = s.user_id and f.status = 'accepted'
           )
           and exists (
             select 1 from follows f
             where f.follower_id = s.user_id and f.followee_id = auth.uid() and f.status = 'accepted'
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

-- As 2026-10-05-coaching.sql, but a coach no longer sees a private post either.
create or replace function can_read_session(sid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select s.user_id = auth.uid()
      or (not s.is_private and (can_view_session(sid) or coaches_rower(s.user_id)))
    from sessions s where s.id = sid
  ), false);
$$;

-- A post's test result follows the post: others can't read it while the post is private (the owner
-- still reads their own through own_row).
create or replace function session_is_private(sid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select s.is_private from sessions s where s.id = sid), false);
$$;
revoke all on function session_is_private(uuid) from public, anon;
grant execute on function session_is_private(uuid) to authenticated;

drop policy if exists read_visible on test_results;
create policy read_visible on test_results for select to authenticated
  using (can_view_user(user_id) and not session_is_private(session_id));

-- MARK: - 3. Making a post private, or visible again

create or replace function set_session_private(p_session uuid, p_private boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  s sessions%rowtype;
  ranked_m int;
  change int;
begin
  select * into s from sessions where id = p_session for update;
  if not found or s.user_id is distinct from auth.uid() then
    raise exception 'You can only change your own posts.';
  end if;
  if s.is_private = p_private then return; end if;

  -- Its leaderboard metres come off while it's private and go back when it's visible.
  ranked_m := case when coalesce(s.is_ranked, false) then s.total_distance_m else 0 end;
  if ranked_m > 0 then
    change := case when p_private then -ranked_m else ranked_m end;
    update daily_totals set
      ranked_distance_m     = greatest(0, ranked_distance_m + change),
      ranked_erg_distance_m = greatest(0, ranked_erg_distance_m + change)
    where user_id = s.user_id and day = s.session_date;
  end if;

  perform set_config('rp.private_change', 'on', true);
  update sessions set is_private = p_private where id = p_session;
  perform set_config('rp.private_change', 'off', true);

  if p_private then
    delete from notifications where session_id = p_session and recipient_id <> s.user_id;
  end if;
end $$;
revoke all on function set_session_private(uuid, boolean) from public, anon;
grant execute on function set_session_private(uuid, boolean) to authenticated;

-- MARK: - 4. Deleting a private post

-- As 2026-10-15-delete-posts.sql, except a private post's leaderboard metres already came off when
-- it was made private, so they aren't taken off twice.
create or replace function delete_session(p_session uuid)
returns text[]
language plpgsql security definer set search_path = public as $$
declare
  s sessions%rowtype;
  paths text[];
  ranked_m int;
begin
  select * into s from sessions where id = p_session;
  if not found or s.user_id is distinct from auth.uid() then
    raise exception 'You can only delete your own posts.';
  end if;

  select coalesce(array_agg(p), '{}') into paths from (
    select monitor_photo_path as p from segments
      where session_id = p_session and monitor_photo_path is not null
    union all
    select path from session_photos where session_id = p_session
  ) photos;

  ranked_m := case when coalesce(s.is_ranked, false) and not s.is_private then s.total_distance_m else 0 end;
  update daily_totals set
    distance_m            = greatest(0, distance_m - s.total_distance_m),
    erg_distance_m        = greatest(0, erg_distance_m - s.total_distance_m),
    session_count         = greatest(0, session_count - 1),
    ranked_distance_m     = greatest(0, ranked_distance_m - ranked_m),
    ranked_erg_distance_m = greatest(0, ranked_erg_distance_m - ranked_m)
  where user_id = s.user_id and day = s.session_date;
  -- A day with nothing left on it goes, so it no longer counts for the streak.
  delete from daily_totals
  where user_id = s.user_id and day = s.session_date and session_count <= 0;

  delete from sessions where id = p_session;
  return paths;
end $$;
revoke all on function delete_session(uuid) from public, anon;
grant execute on function delete_session(uuid) to authenticated;

-- MARK: - 5. Erg event boards

-- As 2026-10-18-challenges-and-erg-events.sql, leaving out private posts.
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
      and not s.is_private
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
revoke all on function erg_event_board(uuid) from public, anon;
grant execute on function erg_event_board(uuid) to authenticated;

commit;

-- The API sees the new column and function straight away.
notify pgrst, 'reload schema';
