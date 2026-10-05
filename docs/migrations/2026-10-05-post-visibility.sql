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
