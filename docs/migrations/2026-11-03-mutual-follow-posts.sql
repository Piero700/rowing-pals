-- Friends: a follower sees your posts only when you follow them back (decision 95, user
-- 2026-11-03). Run once in the Supabase SQL editor, staging first. Safe to run again. One
-- transaction.
--
-- The rule (amends decision 33's): you can see a post if it's yours, or —
--   * neither of you has blocked the other, and
--   * the author's account is public, or you're their approved follower, and
--   * the post's own setting lets you in:
--       "following" (shown as Friends) → you follow each other, both accepted;
--       "club"                         → you're in the author's club;
--       "everyone"                     → either.
-- A one-way follower no longer sees Friends or Everyone posts. Clubmates are unchanged.
-- Not changed: profile stats, test results, rankings and the follows themselves.
--
-- may_notify (alerts) is the same rule for the person being told, so a PB or club alert never
-- points at a post they can't open.

begin;

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
            (s.visibility in ('following', 'everyone')
             and exists (
               select 1 from follows f
               where f.follower_id = recipient and f.followee_id = s.user_id and f.status = 'accepted')
             and exists (
               select 1 from follows f
               where f.follower_id = s.user_id and f.followee_id = recipient and f.status = 'accepted'))
            or (s.visibility in ('club', 'everyone')
                and author.club_id is not null and viewer.club_id = author.club_id)
          )
        )
      )
  );
$$;
revoke all on function may_notify(uuid, uuid, uuid) from public, anon, authenticated;

commit;
