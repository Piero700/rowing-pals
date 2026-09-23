-- ---------------------------------------------------------------
-- Redesign phase E — private accounts and follow requests
-- Run once per Supabase project, in the SQL editor, staging FIRST.
-- Decisions (docs/design/v2-decisions.md #6, plus 2026-09-23 answers):
--   * A private account's sessions, segments, test results, daily
--     totals, reactions and comments are visible only to the owner and
--     to approved followers. Clubmates get no special access.
--   * Private accounts therefore drop off leaderboards for everyone who
--     is not an approved follower (leaderboards read daily_totals /
--     test_results, which are now filtered by the same rule).
--   * The profile row itself (name, club, level) stays readable so the
--     "This profile is private" card and follow requests can show who
--     someone is.
-- The whole file runs in one transaction: if any statement fails,
-- nothing is applied.
-- ---------------------------------------------------------------
begin;

create type follow_status as enum ('pending', 'accepted');

alter table profiles add column is_private boolean not null default false;

-- Every existing follow becomes 'accepted' via the default.
alter table follows add column status follow_status not null default 'accepted';

-- ---------------------------------------------------------------
-- Who may see whose data
-- security definer so the helper can read profiles/follows without
-- being tripped by their own row-level rules; auth.uid() still returns
-- the calling user's id inside it.
-- ---------------------------------------------------------------
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

-- ---------------------------------------------------------------
-- Read policies: replace read_all with visibility-aware ones
-- ---------------------------------------------------------------
drop policy read_all on sessions;
create policy read_visible on sessions for select to authenticated
  using (can_view_user(user_id));

drop policy read_all on segments;
create policy read_visible on segments for select to authenticated
  using (can_view_session(session_id));

drop policy read_all on test_results;
create policy read_visible on test_results for select to authenticated
  using (can_view_user(user_id));

drop policy read_all on daily_totals;
create policy read_visible on daily_totals for select to authenticated
  using (can_view_user(user_id));

drop policy read_all on reactions;
create policy read_visible on reactions for select to authenticated
  using (can_view_session(session_id));

drop policy read_all on comments;
create policy read_visible on comments for select to authenticated
  using (can_view_session(session_id));

-- ---------------------------------------------------------------
-- follows: pending rows are seen only by the two people involved;
-- accepted rows are seen by anyone who can see either end, which is
-- what lets a public profile show its follower/following lists.
-- ---------------------------------------------------------------
drop policy read_all on follows;
drop policy own_row on follows;

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

commit;

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
