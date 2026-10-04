-- Club follow-ups (decision 26). Run once in the Supabase SQL editor, staging first, after
-- docs/migrations/2026-09-30-clubs.sql. Safe to run again.
--
-- 1. Join requests and invitations remember "declined" instead of vanishing, so the rower
--    who asked sees they weren't accepted, and a club sees who turned its invitation down.
-- 2. An invitation sends the invited rower an alert (needs 2026-09-26-notifications.sql).
-- 3. Club pages update live: the club tables join Supabase Realtime.

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
