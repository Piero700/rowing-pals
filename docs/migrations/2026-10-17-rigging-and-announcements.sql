-- Custom rigging and announcements (user, 2026-10-17; decisions 74 and 75).
-- Run once in the Supabase SQL editor, staging first, after 2026-10-16-boats.sql. Safe to run
-- again.
--
-- What it adds:
--   1. Custom rigging: a boat can be stroke-rigged, bow-rigged or custom; a custom boat keeps the
--      side of every seat, bow first ('S' stroke side, 'B' bow side): a bucket four is 'SBBS'.
--   2. Announcements: a coach posts a heading and a message to every rower in the club, on their
--      Feed for as long as the coach chooses (24 hours unless they say otherwise), with an alert if
--      they want one. Any coach, the owner or a co-owner can edit or delete one.

begin;

-- MARK: - 1. Custom rigging

alter table saved_boats add column if not exists sides text;
alter table session_boats add column if not exists sides text;
alter table saved_boats drop constraint if exists saved_boats_rigging_check;
alter table saved_boats add constraint saved_boats_rigging_check check (rigging in ('stroke', 'bow', 'custom'));
alter table session_boats drop constraint if exists session_boats_rigging_check;
alter table session_boats add constraint session_boats_rigging_check check (rigging in ('stroke', 'bow', 'custom'));
alter table saved_boats drop constraint if exists saved_boats_sides_valid;
alter table saved_boats add constraint saved_boats_sides_valid check (sides is null or sides ~ '^[SB]{2,8}$');
alter table session_boats drop constraint if exists session_boats_sides_valid;
alter table session_boats add constraint session_boats_sides_valid check (sides is null or sides ~ '^[SB]{2,8}$');

-- A boat's rigging and sides, as they're stored: custom needs a side for every seat of a sweep
-- boat; otherwise there are none. Returns the sides to keep. Internal.
create or replace function checked_sides(p_type text, p_rigging text, p_sides text)
returns text
language plpgsql immutable as $$
begin
  if coalesce(p_rigging, 'stroke') not in ('stroke', 'bow', 'custom') then raise exception 'Choose the rigging.'; end if;
  if p_rigging = 'custom' then
    if p_type in ('1x', '2x', '4x') then raise exception 'Sculling boats have no sides to set.'; end if;
    if p_sides is null or p_sides !~ '^[SB]+$' or char_length(p_sides) <> boat_rowers(p_type) then
      raise exception 'Give every seat a side.';
    end if;
    return p_sides;
  end if;
  return null;
end $$;

drop function if exists save_saved_boat(uuid, text, text, text, jsonb);
create or replace function save_saved_boat(p_saved uuid, p_name text, p_type text, p_rigging text, p_sides text, p_seats jsonb)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid := p_saved;
  v_sides text := checked_sides(p_type, p_rigging, p_sides);
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then raise exception 'Only your club''s coaches can save boats.'; end if;
  perform check_crew(v_club, p_type, p_seats);
  if v_id is null then
    insert into saved_boats (club_id, name, boat_type, rigging, sides, created_by)
    values (v_club, btrim(p_name), p_type, coalesce(p_rigging, 'stroke'), v_sides, auth.uid())
    returning id into v_id;
  else
    update saved_boats set name = btrim(p_name), boat_type = p_type, rigging = coalesce(p_rigging, 'stroke'), sides = v_sides
    where id = v_id and club_id = v_club;
    if not found then raise exception 'That saved boat no longer exists.'; end if;
    delete from saved_boat_seats where saved_boat_id = v_id;
  end if;
  insert into saved_boat_seats (saved_boat_id, seat, user_id)
    select v_id, (v ->> 'seat')::int, (v ->> 'user')::uuid from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v;
  return v_id;
end $$;

-- As before (2026-10-16-boats.sql), with the sides: a sent boat whose rigging or sides change goes
-- back to Not sent too.
drop function if exists save_session_boat(uuid, uuid, text, text, text, jsonb, boolean);
create or replace function save_session_boat(
  p_boat uuid, p_session uuid, p_name text, p_type text, p_rigging text, p_sides text, p_seats jsonb, p_keep_saved boolean
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_session water_sessions;
  v_id uuid := p_boat;
  v_old session_boats;
  v_old_seats jsonb;
  v_new_seats jsonb;
  v_clash text;
  v_saved uuid;
  v_sides text := checked_sides(p_type, p_rigging, p_sides);
begin
  select * into v_session from water_sessions where id = p_session;
  if v_session.id is null then raise exception 'That water session no longer exists.'; end if;
  if not is_club_coach(v_session.club_id) then raise exception 'Only your club''s coaches can crew boats.'; end if;
  perform check_crew(v_session.club_id, p_type, p_seats);

  select p.display_name || ' is already in ' || b.name into v_clash
  from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v
  join session_boat_seats s on s.user_id = (v ->> 'user')::uuid
  join session_boats b on b.id = s.boat_id and b.session_id = p_session and b.id is distinct from p_boat
  join profiles p on p.id = s.user_id
  limit 1;
  if v_clash is not null then raise exception '%.', v_clash; end if;

  v_new_seats := coalesce((select jsonb_agg(jsonb_build_object('seat', (v ->> 'seat')::int, 'user', v ->> 'user') order by (v ->> 'seat')::int)
                           from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v), '[]'::jsonb);

  if v_id is null then
    insert into session_boats (session_id, position, name, boat_type, rigging, sides)
    values (p_session, coalesce((select max(position) + 1 from session_boats where session_id = p_session), 0),
            btrim(p_name), p_type, coalesce(p_rigging, 'stroke'), v_sides)
    returning id into v_id;
  else
    select * into v_old from session_boats where id = v_id and session_id = p_session;
    if v_old.id is null then raise exception 'That boat no longer exists.'; end if;
    v_old_seats := coalesce((select jsonb_agg(jsonb_build_object('seat', s.seat, 'user', s.user_id::text) order by s.seat)
                             from session_boat_seats s where s.boat_id = v_id), '[]'::jsonb);
    update session_boats set
      name = btrim(p_name), boat_type = p_type, rigging = coalesce(p_rigging, 'stroke'), sides = v_sides,
      sent_at = case when v_old.name = btrim(p_name) and v_old.boat_type = p_type
                          and v_old.rigging = coalesce(p_rigging, 'stroke') and v_old.sides is not distinct from v_sides
                          and v_old_seats = v_new_seats
                     then v_old.sent_at end
    where id = v_id;
    delete from session_boat_seats where boat_id = v_id;
  end if;
  insert into session_boat_seats (boat_id, seat, user_id)
    select v_id, (v ->> 'seat')::int, (v ->> 'user')::uuid from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v;

  if coalesce(p_keep_saved, false) then
    v_saved := save_saved_boat((select saved_boat_id from session_boats where id = v_id), p_name, p_type, p_rigging, v_sides, p_seats);
    update session_boats set saved_boat_id = v_saved where id = v_id;
  else
    update session_boats set saved_boat_id = null where id = v_id;
  end if;
  return v_id;
end $$;

-- Adding a saved boat keeps its sides too.
create or replace function add_saved_boat(p_saved uuid, p_session uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_session water_sessions;
  v_saved saved_boats;
  v_id uuid;
begin
  select * into v_session from water_sessions where id = p_session;
  select * into v_saved from saved_boats where id = p_saved;
  if v_session.id is null or v_saved.id is null then raise exception 'That boat or session no longer exists.'; end if;
  if not is_club_coach(v_session.club_id) or v_saved.club_id <> v_session.club_id then
    raise exception 'Only your club''s coaches can crew boats.';
  end if;
  insert into session_boats (session_id, position, name, boat_type, rigging, sides, saved_boat_id)
  values (p_session, coalesce((select max(position) + 1 from session_boats where session_id = p_session), 0),
          v_saved.name, v_saved.boat_type, v_saved.rigging, v_saved.sides, v_saved.id)
  returning id into v_id;
  insert into session_boat_seats (boat_id, seat, user_id)
    select v_id, s.seat, s.user_id from saved_boat_seats s
    where s.saved_boat_id = p_saved
      and not exists (
        select 1 from session_boat_seats o join session_boats b on b.id = o.boat_id
        where b.session_id = p_session and b.id <> v_id and o.user_id = s.user_id
      );
  return v_id;
end $$;

-- MARK: - 2. Announcements

create table if not exists announcements (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references clubs on delete cascade,
  heading    text not null check (char_length(btrim(heading)) between 1 and 80),
  message    text check (message is null or char_length(message) <= 2000),
  -- On rowers' Feeds until then.
  expires_at timestamptz not null,
  created_by uuid references profiles on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists announcements_club_expiry on announcements (club_id, expires_at desc);

-- Coaches, the owner and co-owners look after a club's announcements.
create or replace function can_manage_announcements(p_club uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select is_club_coach(p_club) or exists (
    select 1 from profiles p where p.id = auth.uid() and p.club_id = p_club and p.club_role in ('owner', 'co_owner')
  );
$$;

alter table announcements enable row level security;
drop policy if exists read_own_club on announcements;
create policy read_own_club on announcements for select to authenticated
  using (club_id = (select p.club_id from profiles p where p.id = auth.uid()));

-- Post one (coaches). p_alert: every rower in the club also gets "New announcement". Returns its id.
create or replace function post_announcement(p_heading text, p_message text, p_expires_at timestamptz, p_alert boolean)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then raise exception 'Only your club''s coaches can post announcements.'; end if;
  if p_expires_at <= now() then raise exception 'Choose a time in the future for it to come off the Feed.'; end if;
  insert into announcements (club_id, heading, message, expires_at, created_by)
  values (v_club, btrim(p_heading), nullif(btrim(coalesce(p_message, '')), ''), p_expires_at, auth.uid())
  returning id into v_id;
  if coalesce(p_alert, false) then
    begin
      insert into notifications (recipient_id, actor_id, kind, club_id, announcement_id)
      select p.id, auth.uid(), 'announcement', v_club, v_id
      from profiles p
      where p.club_id = v_club and p.is_rower and p.id <> auth.uid()
        and not exists (
          select 1 from blocks b
          where (b.blocker_id = p.id and b.blocked_id = auth.uid())
             or (b.blocker_id = auth.uid() and b.blocked_id = p.id)
        );
    exception when others then
      raise warning 'announcement alerts: %', sqlerrm;
    end;
  end if;
  return v_id;
end $$;

create or replace function update_announcement(p_announcement uuid, p_heading text, p_message text, p_expires_at timestamptz)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update announcements a set
    heading = btrim(p_heading), message = nullif(btrim(coalesce(p_message, '')), ''),
    expires_at = p_expires_at, updated_at = now()
  where a.id = p_announcement and can_manage_announcements(a.club_id);
  if not found then raise exception 'Only your club''s coaches and owners can change announcements.'; end if;
end $$;

create or replace function delete_announcement(p_announcement uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from announcements a where a.id = p_announcement and can_manage_announcements(a.club_id);
end $$;

-- MARK: - Alerts

do $$
begin
  if to_regclass('public.notifications') is null then
    raise notice 'No notifications table: run 2026-09-26-notifications.sql, then this file again, for announcement alerts.';
    return;
  end if;
  alter table notifications add column if not exists announcement_id uuid references announcements on delete cascade;
  alter table notifications drop constraint if exists notifications_kind_check;
  alter table notifications add constraint notifications_kind_check
    check (kind in ('comment', 'reply', 'pb', 'club_post', 'club_invite', 'new_workout',
                    'new_practice', 'practice_changed', 'practice_cancelled', 'practice_reminder', 'new_event',
                    'boat_seat', 'announcement'));
end $$;

-- MARK: - Who may call what

revoke all on function checked_sides(text, text, text) from public, anon, authenticated;
revoke all on function save_saved_boat(uuid, text, text, text, text, jsonb) from public, anon;
grant execute on function save_saved_boat(uuid, text, text, text, text, jsonb) to authenticated;
revoke all on function save_session_boat(uuid, uuid, text, text, text, text, jsonb, boolean) from public, anon;
grant execute on function save_session_boat(uuid, uuid, text, text, text, text, jsonb, boolean) to authenticated;
revoke all on function can_manage_announcements(uuid) from public, anon;
grant execute on function can_manage_announcements(uuid) to authenticated;
revoke all on function post_announcement(text, text, timestamptz, boolean) from public, anon;
grant execute on function post_announcement(text, text, timestamptz, boolean) to authenticated;
revoke all on function update_announcement(uuid, text, text, timestamptz) from public, anon;
grant execute on function update_announcement(uuid, text, text, timestamptz) to authenticated;
revoke all on function delete_announcement(uuid) from public, anon;
grant execute on function delete_announcement(uuid) to authenticated;

commit;
