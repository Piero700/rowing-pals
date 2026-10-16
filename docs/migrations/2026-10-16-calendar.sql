-- Coach version, phase CV2: the Calendar and attendance (decisions 39, 68, 69; user 2026-10-16).
-- Run once in the Supabase SQL editor, staging first, after 2026-10-05-coaching.sql and
-- 2026-10-16-coach-version.sql. Safe to run again.
--
-- What it adds:
--   1. The club's week: Monday or Sunday, set by its coaches (decision 69).
--   2. Practices written by coaches: one-off or every week until a date; edit or cancel one or
--      the rest of the series. Each has a short "what" (Water, Erg, Circuits…).
--   3. A rower's answer to each practice — Available or Can't, with a reason only coaches see —
--      until it starts, and a check-in from 30 minutes before (decision 68).
--   4. The register: the coach's Present / Late / Absent / Excused, which always counts, with
--      every change kept (decision 39).
--   5. Term dates for attendance totals.
--   6. Races, regattas and other events, and "Can you race?" (decision 68).
--   7. Alerts: a practice changed or cancelled, a new race or event, and a reminder two hours
--      before a practice (Settings → Practice reminders), queued every five minutes by pg_cron.

begin;

-- MARK: - 1. The club's week (decision 69)

alter table clubs add column if not exists week_starts_on text not null default 'monday';
alter table clubs drop constraint if exists clubs_week_starts_on_valid;
alter table clubs add constraint clubs_week_starts_on_valid check (week_starts_on in ('monday', 'sunday'));

create or replace function set_club_week_start(p_day text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then
    raise exception 'Only your club''s coaches can change its week.';
  end if;
  if p_day not in ('monday', 'sunday') then raise exception 'A week starts on Monday or Sunday.'; end if;
  update clubs set week_starts_on = p_day where id = v_club;
end $$;

-- MARK: - 2. Practices

alter table practices add column if not exists title text;
alter table practices drop constraint if exists practices_title_length;
alter table practices add constraint practices_title_length check (title is null or char_length(title) <= 40);

-- Every rowing member a practice is for: the whole club, or its squads' members.
create or replace function practice_audience(p_practice uuid)
returns setof uuid
language sql stable security definer set search_path = public as $$
  select p.id
  from practices pr
  join profiles p on p.club_id = pr.club_id and p.is_rower
  where pr.id = p_practice
    and (
      not exists (select 1 from practice_squads ps where ps.practice_id = pr.id)
      or exists (
        select 1 from practice_squads ps
        join squad_members sm on sm.squad_id = ps.squad_id and sm.user_id = p.id
        where ps.practice_id = pr.id
      )
    );
$$;

-- For the coach's Calendar, register and Who's available: who each practice is for, in one call.
create or replace function practice_audiences(p_practices uuid[])
returns table (practice_id uuid, user_id uuid)
language sql stable security definer set search_path = public as $$
  select pr.id, a.id
  from practices pr
  cross join lateral practice_audience(pr.id) as a(id)
  where pr.id = any(coalesce(p_practices, '{}')) and is_club_coach(pr.club_id);
$$;

-- Tell everyone a practice is for (but the coach) that it changed or was cancelled. Internal.
create or replace function notify_practice(p_practice uuid, p_kind text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into notifications (recipient_id, actor_id, kind, club_id, practice_id)
  select a.id, auth.uid(), p_kind, pr.club_id, pr.id
  from practices pr
  cross join lateral practice_audience(pr.id) as a(id)
  where pr.id = p_practice
    and a.id <> auth.uid()
    and not exists (
      select 1 from blocks b
      where (b.blocker_id = a.id and b.blocked_id = auth.uid())
         or (b.blocker_id = auth.uid() and b.blocked_id = a.id)
    );
exception when others then
  -- An alert problem must never stop the practice being saved.
  raise warning 'practice alerts: %', sqlerrm;
end $$;

-- Create a practice (coaches only). With p_repeat_until, one every week on the same day until
-- that day, as one series; times stay the same local time across clock changes (p_time_zone).
-- Squads outside the club are ignored; none means the whole club. Returns the first one's id.
create or replace function create_practice(
  p_title text, p_place text, p_starts_at timestamptz, p_ends_at timestamptz, p_squads uuid[],
  p_repeat_until date, p_remind boolean, p_time_zone text
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_series uuid := case when p_repeat_until is null then null else gen_random_uuid() end;
  v_tz text := coalesce(nullif(p_time_zone, ''), 'Europe/London');
  v_local_start timestamp := p_starts_at at time zone v_tz;
  v_local_end timestamp := p_ends_at at time zone v_tz;
  v_first uuid;
  v_id uuid;
  v_week int := 0;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then
    raise exception 'Only your club''s coaches can set practices.';
  end if;
  if p_ends_at <= p_starts_at then raise exception 'A practice has to end after it starts.'; end if;
  if p_repeat_until is not null and p_repeat_until < v_local_start::date then
    raise exception 'Repeat until a day on or after the first practice.';
  end if;

  loop
    exit when v_week > 0 and (p_repeat_until is null or (v_local_start + v_week * interval '7 days')::date > p_repeat_until);
    exit when v_week >= 60;
    insert into practices (club_id, series_id, starts_at, ends_at, title, place, remind, created_by)
    values (v_club, v_series,
            (v_local_start + v_week * interval '7 days') at time zone v_tz,
            (v_local_end + v_week * interval '7 days') at time zone v_tz,
            nullif(btrim(coalesce(p_title, '')), ''), nullif(btrim(coalesce(p_place, '')), ''),
            coalesce(p_remind, true), auth.uid())
    returning id into v_id;
    insert into practice_squads (practice_id, squad_id)
      select v_id, s.id from squads s where s.id = any(coalesce(p_squads, '{}')) and s.club_id = v_club;
    v_first := coalesce(v_first, v_id);
    v_week := v_week + 1;
  end loop;
  return v_first;
end $$;

-- Change a practice (its club's coaches). p_rest_of_series: this one and every later one in its
-- series take the new what, place, squads, reminder and local start and end times (each keeps
-- its own day). Otherwise only this one changes, its day too. Everyone it's for is told.
create or replace function update_practice(
  p_practice uuid, p_rest_of_series boolean, p_title text, p_place text,
  p_starts_at timestamptz, p_ends_at timestamptz, p_squads uuid[], p_remind boolean, p_time_zone text
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_row practices;
  v_tz text := coalesce(nullif(p_time_zone, ''), 'Europe/London');
  v_start_time time := (p_starts_at at time zone v_tz)::time;
  v_end_time time := (p_ends_at at time zone v_tz)::time;
  v_target uuid;
begin
  select * into v_row from practices where id = p_practice;
  if v_row.id is null then raise exception 'That practice no longer exists.'; end if;
  if not is_club_coach(v_row.club_id) then raise exception 'Only your club''s coaches can change practices.'; end if;
  if p_ends_at <= p_starts_at then raise exception 'A practice has to end after it starts.'; end if;

  for v_target in
    select pr.id from practices pr
    where pr.id = p_practice
       or (coalesce(p_rest_of_series, false) and v_row.series_id is not null
           and pr.series_id = v_row.series_id and pr.starts_at >= v_row.starts_at and not pr.cancelled)
  loop
    update practices pr set
      title = nullif(btrim(coalesce(p_title, '')), ''),
      place = nullif(btrim(coalesce(p_place, '')), ''),
      remind = coalesce(p_remind, true),
      starts_at = case when pr.id = p_practice and not coalesce(p_rest_of_series, false) then p_starts_at
                       else ((pr.starts_at at time zone v_tz)::date + v_start_time) at time zone v_tz end,
      ends_at = case when pr.id = p_practice and not coalesce(p_rest_of_series, false) then p_ends_at
                     else ((pr.starts_at at time zone v_tz)::date + v_end_time) at time zone v_tz end
    where pr.id = v_target;
    delete from practice_squads where practice_id = v_target;
    insert into practice_squads (practice_id, squad_id)
      select v_target, s.id from squads s where s.id = any(coalesce(p_squads, '{}')) and s.club_id = v_row.club_id;
  end loop;
  perform notify_practice(p_practice, 'practice_changed');
end $$;

-- Cancel a practice, or it and every later one in its series. Everyone it was for is told.
create or replace function cancel_practice(p_practice uuid, p_rest_of_series boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_row practices;
begin
  select * into v_row from practices where id = p_practice;
  if v_row.id is null then return; end if;
  if not is_club_coach(v_row.club_id) then raise exception 'Only your club''s coaches can cancel practices.'; end if;
  update practices set cancelled = true
  where id = p_practice
     or (coalesce(p_rest_of_series, false) and v_row.series_id is not null
         and series_id = v_row.series_id and starts_at >= v_row.starts_at);
  perform notify_practice(p_practice, 'practice_cancelled');
end $$;

-- The rower's own practices between two instants (their Calendar and Feed card). A coach who
-- rows sees here only the practices for them, not every practice they can read.
create or replace function my_practices(p_from timestamptz, p_to timestamptz)
returns setof practices
language sql stable security definer set search_path = public as $$
  select pr.* from practices pr
  where pr.starts_at >= p_from and pr.starts_at < p_to and practice_is_for_me(pr.id)
  order by pr.starts_at;
$$;

-- MARK: - 3. A rower's answer and check-in

-- Available ('going') or Can't ('cant'), with an optional reason, until the practice starts.
-- Null clears the answer.
create or replace function respond_practice(p_practice uuid, p_answer text, p_reason text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_row practices;
begin
  select * into v_row from practices where id = p_practice;
  if v_row.id is null or v_row.cancelled then raise exception 'That practice isn''t on any more.'; end if;
  if not practice_is_for_me(p_practice) then raise exception 'That practice isn''t for you.'; end if;
  if now() >= v_row.starts_at then raise exception 'That practice has started: your answer can''t change now.'; end if;
  if p_answer is not null and p_answer not in ('going', 'cant') then raise exception 'Answer Available or Can''t.'; end if;
  insert into attendance_responses (practice_id, user_id, answer, reason, updated_at)
  values (p_practice, auth.uid(), p_answer,
          case when p_answer = 'cant' then nullif(btrim(coalesce(p_reason, '')), '') end, now())
  on conflict (practice_id, user_id) do update
    set answer = excluded.answer, reason = excluded.reason, updated_at = now();
end $$;

-- Check in from 30 minutes before the start until the end; it counts as Available.
create or replace function check_in_practice(p_practice uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_row practices;
begin
  select * into v_row from practices where id = p_practice;
  if v_row.id is null or v_row.cancelled then raise exception 'That practice isn''t on any more.'; end if;
  if not practice_is_for_me(p_practice) then raise exception 'That practice isn''t for you.'; end if;
  if now() < v_row.starts_at - interval '30 minutes' then raise exception 'Check-in opens 30 minutes before the start.'; end if;
  if now() > v_row.ends_at then raise exception 'That practice has finished.'; end if;
  insert into attendance_responses (practice_id, user_id, answer, checked_in_at, updated_at)
  values (p_practice, auth.uid(), 'going', now(), now())
  on conflict (practice_id, user_id) do update
    set answer = 'going', reason = null, checked_in_at = now(), updated_at = now();
end $$;

-- MARK: - 4. The register (decision 39)

-- Set marks for a practice, as [{"user_id": "…", "mark": "present"}, …]; a null mark clears one.
-- Only changed marks are written and logged, with who set them and when.
create or replace function set_attendance_marks(p_practice uuid, p_marks jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_item jsonb;
  v_user uuid;
  v_mark text;
begin
  select club_id into v_club from practices where id = p_practice;
  if v_club is null then raise exception 'That practice no longer exists.'; end if;
  if not is_club_coach(v_club) then raise exception 'Only your club''s coaches can take the register.'; end if;
  for v_item in select * from jsonb_array_elements(coalesce(p_marks, '[]'::jsonb)) loop
    v_user := (v_item ->> 'user_id')::uuid;
    v_mark := v_item ->> 'mark';
    if not exists (select 1 from profiles where id = v_user and club_id = v_club) then continue; end if;
    if v_mark is null then
      delete from attendance_marks where practice_id = p_practice and user_id = v_user;
    elsif v_mark in ('present', 'late', 'absent', 'excused') then
      if not exists (select 1 from attendance_marks where practice_id = p_practice and user_id = v_user and mark = v_mark) then
        insert into attendance_marks (practice_id, user_id, mark, set_by, set_at)
        values (p_practice, v_user, v_mark, auth.uid(), now())
        on conflict (practice_id, user_id) do update set mark = excluded.mark, set_by = excluded.set_by, set_at = now();
        insert into attendance_mark_log (practice_id, user_id, mark, set_by) values (p_practice, v_user, v_mark, auth.uid());
      end if;
    end if;
  end loop;
end $$;

-- MARK: - 5. Terms

create or replace function save_club_term(p_term uuid, p_name text, p_starts_on date, p_ends_on date)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then raise exception 'Only your club''s coaches can set term dates.'; end if;
  if coalesce(char_length(btrim(p_name)), 0) = 0 then raise exception 'Give the term a name.'; end if;
  if p_ends_on < p_starts_on then raise exception 'A term has to end on or after the day it starts.'; end if;
  if p_term is null then
    insert into club_terms (club_id, name, starts_on, ends_on) values (v_club, btrim(p_name), p_starts_on, p_ends_on)
    returning id into v_id;
  else
    update club_terms set name = btrim(p_name), starts_on = p_starts_on, ends_on = p_ends_on
    where id = p_term and club_id = v_club returning id into v_id;
  end if;
  return v_id;
end $$;

create or replace function delete_club_term(p_term uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from club_terms t where t.id = p_term and is_club_coach(t.club_id);
end $$;

-- MARK: - 6. Races, regattas and other events (decision 68)

create table if not exists club_events (
  id                uuid primary key default gen_random_uuid(),
  club_id           uuid not null references clubs on delete cascade,
  kind              text not null check (kind in ('race', 'event')),
  name              text not null check (char_length(btrim(name)) between 1 and 60),
  first_day         date not null,
  last_day          date not null,
  place             text check (place is null or char_length(place) <= 80),
  note              text check (note is null or char_length(note) <= 400),
  asks_availability boolean not null default true,
  created_by        uuid references profiles on delete set null,
  created_at        timestamptz not null default now(),
  check (last_day >= first_day)
);
create index if not exists club_events_club_day on club_events (club_id, first_day);

-- Empty for the whole club.
create table if not exists event_squads (
  event_id uuid not null references club_events on delete cascade,
  squad_id uuid not null references squads on delete cascade,
  primary key (event_id, squad_id)
);

-- "Can you race?": yes or no, with an optional reason only coaches see.
create table if not exists event_responses (
  event_id   uuid not null references club_events on delete cascade,
  user_id    uuid not null references profiles on delete cascade,
  answer     text not null check (answer in ('yes', 'no')),
  reason     text check (reason is null or char_length(reason) <= 200),
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create or replace function event_audience(p_event uuid)
returns setof uuid
language sql stable security definer set search_path = public as $$
  select p.id
  from club_events e
  join profiles p on p.club_id = e.club_id and p.is_rower
  where e.id = p_event
    and (
      not exists (select 1 from event_squads es where es.event_id = e.id)
      or exists (
        select 1 from event_squads es
        join squad_members sm on sm.squad_id = es.squad_id and sm.user_id = p.id
        where es.event_id = e.id
      )
    );
$$;

create or replace function event_is_for_me(p_event uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() in (select event_audience(p_event));
$$;

-- The rower's own races and events that haven't finished yet (their Calendar).
create or replace function my_events(p_from date)
returns setof club_events
language sql stable security definer set search_path = public as $$
  select e.* from club_events e
  where e.last_day >= p_from and event_is_for_me(e.id)
  order by e.first_day;
$$;

create or replace function event_audiences(p_events uuid[])
returns table (event_id uuid, user_id uuid)
language sql stable security definer set search_path = public as $$
  select e.id, a.id
  from club_events e
  cross join lateral event_audience(e.id) as a(id)
  where e.id = any(coalesce(p_events, '{}')) and is_club_coach(e.club_id);
$$;

alter table club_events enable row level security;
alter table event_squads enable row level security;
alter table event_responses enable row level security;

-- Every member sees their club's events (they're in everyone's calendar); answers as practices.
drop policy if exists read_own_club on club_events;
create policy read_own_club on club_events for select to authenticated
  using (club_id = (select p.club_id from profiles p where p.id = auth.uid()));
drop policy if exists read_own_club on event_squads;
create policy read_own_club on event_squads for select to authenticated
  using (exists (
    select 1 from club_events e where e.id = event_id
      and e.club_id = (select p.club_id from profiles p where p.id = auth.uid())
  ));
drop policy if exists read_own_or_coach on event_responses;
create policy read_own_or_coach on event_responses for select to authenticated
  using (user_id = auth.uid() or exists (
    select 1 from club_events e where e.id = event_id and is_club_coach(e.club_id)
  ));

-- Add a race or event (coaches only). Everyone it's for is told.
create or replace function create_event(
  p_kind text, p_name text, p_first_day date, p_last_day date, p_place text, p_note text,
  p_asks_availability boolean, p_squads uuid[]
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then raise exception 'Only your club''s coaches can add races and events.'; end if;
  if p_kind not in ('race', 'event') then raise exception 'Choose a race or an event.'; end if;
  if coalesce(char_length(btrim(p_name)), 0) = 0 then raise exception 'Give it a name.'; end if;
  if coalesce(p_last_day, p_first_day) < p_first_day then raise exception 'The last day can''t be before the first.'; end if;
  insert into club_events (club_id, kind, name, first_day, last_day, place, note, asks_availability, created_by)
  values (v_club, p_kind, btrim(p_name), p_first_day, coalesce(p_last_day, p_first_day),
          nullif(btrim(coalesce(p_place, '')), ''), nullif(btrim(coalesce(p_note, '')), ''),
          coalesce(p_asks_availability, true), auth.uid())
  returning id into v_id;
  insert into event_squads (event_id, squad_id)
    select v_id, s.id from squads s where s.id = any(coalesce(p_squads, '{}')) and s.club_id = v_club;
  begin
    insert into notifications (recipient_id, actor_id, kind, club_id, event_id)
    select a.id, auth.uid(), 'new_event', v_club, v_id
    from event_audience(v_id) as a(id)
    where a.id <> auth.uid()
      and not exists (
        select 1 from blocks b
        where (b.blocker_id = a.id and b.blocked_id = auth.uid())
           or (b.blocker_id = auth.uid() and b.blocked_id = a.id)
      );
  exception when others then
    raise warning 'create_event alerts: %', sqlerrm;
  end;
  return v_id;
end $$;

create or replace function update_event(
  p_event uuid, p_kind text, p_name text, p_first_day date, p_last_day date, p_place text, p_note text,
  p_asks_availability boolean, p_squads uuid[]
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from club_events where id = p_event;
  if v_club is null then raise exception 'That event no longer exists.'; end if;
  if not is_club_coach(v_club) then raise exception 'Only your club''s coaches can change races and events.'; end if;
  if p_kind not in ('race', 'event') then raise exception 'Choose a race or an event.'; end if;
  if coalesce(char_length(btrim(p_name)), 0) = 0 then raise exception 'Give it a name.'; end if;
  if coalesce(p_last_day, p_first_day) < p_first_day then raise exception 'The last day can''t be before the first.'; end if;
  update club_events set kind = p_kind, name = btrim(p_name), first_day = p_first_day,
    last_day = coalesce(p_last_day, p_first_day), place = nullif(btrim(coalesce(p_place, '')), ''),
    note = nullif(btrim(coalesce(p_note, '')), ''), asks_availability = coalesce(p_asks_availability, true)
  where id = p_event;
  delete from event_squads where event_id = p_event;
  insert into event_squads (event_id, squad_id)
    select p_event, s.id from squads s where s.id = any(coalesce(p_squads, '{}')) and s.club_id = v_club;
end $$;

create or replace function delete_event(p_event uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from club_events e where e.id = p_event and is_club_coach(e.club_id);
end $$;

-- "Can you race?" until the race's last day is over. Null clears the answer.
create or replace function respond_event(p_event uuid, p_answer text, p_reason text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_row club_events;
begin
  select * into v_row from club_events where id = p_event;
  if v_row.id is null then raise exception 'That event no longer exists.'; end if;
  if not v_row.asks_availability then raise exception 'Your coach isn''t asking about this one.'; end if;
  if not event_is_for_me(p_event) then raise exception 'That event isn''t for you.'; end if;
  if current_date > v_row.last_day then raise exception 'That event is over.'; end if;
  if p_answer is null then
    delete from event_responses where event_id = p_event and user_id = auth.uid();
    return;
  end if;
  if p_answer not in ('yes', 'no') then raise exception 'Answer Available or Can''t.'; end if;
  insert into event_responses (event_id, user_id, answer, reason, updated_at)
  values (p_event, auth.uid(), p_answer,
          case when p_answer = 'no' then nullif(btrim(coalesce(p_reason, '')), '') end, now())
  on conflict (event_id, user_id) do update set answer = excluded.answer, reason = excluded.reason, updated_at = now();
end $$;

-- MARK: - 7. Alerts

-- Settings → Notifications → Practice reminders: on unless the rower turns it off.
alter table notification_settings add column if not exists practice_reminders boolean not null default true;

do $$
begin
  if to_regclass('public.notifications') is null then
    raise notice 'No notifications table: run 2026-09-26-notifications.sql, then this file again, for calendar alerts.';
    return;
  end if;
  alter table notifications add column if not exists practice_id uuid references practices on delete cascade;
  alter table notifications add column if not exists event_id uuid references club_events on delete cascade;
  alter table notifications drop constraint if exists notifications_kind_check;
  alter table notifications add constraint notifications_kind_check
    check (kind in ('comment', 'reply', 'pb', 'club_post', 'club_invite', 'new_workout',
                    'practice_changed', 'practice_cancelled', 'practice_reminder', 'new_event'));
end $$;

-- Two hours before each practice that has its reminder on, everyone it's for who hasn't said
-- Can't (and hasn't turned Practice reminders off) gets "Practice in 2 hours". Run every five
-- minutes; each practice reminds each rower once.
create or replace function queue_practice_reminders()
returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into notifications (recipient_id, actor_id, kind, club_id, practice_id)
  select a.id, coalesce(pr.created_by, a.id), 'practice_reminder', pr.club_id, pr.id
  from practices pr
  cross join lateral practice_audience(pr.id) as a(id)
  left join attendance_responses r on r.practice_id = pr.id and r.user_id = a.id
  left join notification_settings ns on ns.user_id = a.id
  where not pr.cancelled and pr.remind
    and pr.starts_at > now() + interval '1 hour 55 minutes'
    and pr.starts_at <= now() + interval '2 hours'
    and coalesce(r.answer, 'going') <> 'cant'
    and coalesce(ns.practice_reminders, true)
    and not exists (
      select 1 from notifications n
      where n.practice_id = pr.id and n.recipient_id = a.id and n.kind = 'practice_reminder'
    );
end $$;

-- MARK: - Access to the functions

revoke all on function set_club_week_start(text) from public, anon;
grant execute on function set_club_week_start(text) to authenticated;
revoke all on function practice_audience(uuid) from public, anon, authenticated;
revoke all on function notify_practice(uuid, text) from public, anon, authenticated;
revoke all on function practice_audiences(uuid[]) from public, anon;
grant execute on function practice_audiences(uuid[]) to authenticated;
revoke all on function create_practice(text, text, timestamptz, timestamptz, uuid[], date, boolean, text) from public, anon;
grant execute on function create_practice(text, text, timestamptz, timestamptz, uuid[], date, boolean, text) to authenticated;
revoke all on function update_practice(uuid, boolean, text, text, timestamptz, timestamptz, uuid[], boolean, text) from public, anon;
grant execute on function update_practice(uuid, boolean, text, text, timestamptz, timestamptz, uuid[], boolean, text) to authenticated;
revoke all on function cancel_practice(uuid, boolean) from public, anon;
grant execute on function cancel_practice(uuid, boolean) to authenticated;
revoke all on function my_practices(timestamptz, timestamptz) from public, anon;
grant execute on function my_practices(timestamptz, timestamptz) to authenticated;
revoke all on function my_events(date) from public, anon;
grant execute on function my_events(date) to authenticated;
revoke all on function respond_practice(uuid, text, text) from public, anon;
grant execute on function respond_practice(uuid, text, text) to authenticated;
revoke all on function check_in_practice(uuid) from public, anon;
grant execute on function check_in_practice(uuid) to authenticated;
revoke all on function set_attendance_marks(uuid, jsonb) from public, anon;
grant execute on function set_attendance_marks(uuid, jsonb) to authenticated;
revoke all on function save_club_term(uuid, text, date, date) from public, anon;
grant execute on function save_club_term(uuid, text, date, date) to authenticated;
revoke all on function delete_club_term(uuid) from public, anon;
grant execute on function delete_club_term(uuid) to authenticated;
revoke all on function event_audience(uuid) from public, anon, authenticated;
revoke all on function event_is_for_me(uuid) from public, anon;
grant execute on function event_is_for_me(uuid) to authenticated;
revoke all on function event_audiences(uuid[]) from public, anon;
grant execute on function event_audiences(uuid[]) to authenticated;
revoke all on function create_event(text, text, date, date, text, text, boolean, uuid[]) from public, anon;
grant execute on function create_event(text, text, date, date, text, text, boolean, uuid[]) to authenticated;
revoke all on function update_event(uuid, text, text, date, date, text, text, boolean, uuid[]) from public, anon;
grant execute on function update_event(uuid, text, text, date, date, text, text, boolean, uuid[]) to authenticated;
revoke all on function delete_event(uuid) from public, anon;
grant execute on function delete_event(uuid) to authenticated;
revoke all on function respond_event(uuid, text, text) from public, anon;
grant execute on function respond_event(uuid, text, text) to authenticated;
revoke all on function queue_practice_reminders() from public, anon, authenticated;

commit;

-- MARK: - The reminder job (outside the transaction: pg_cron runs on its own)
-- Supabase: if this line fails, turn on pg_cron under Database → Extensions, then run the rest.
create extension if not exists pg_cron;
select cron.unschedule(jobid) from cron.job where jobname = 'practice-reminders';
select cron.schedule('practice-reminders', '*/5 * * * *', 'select public.queue_practice_reminders()');
