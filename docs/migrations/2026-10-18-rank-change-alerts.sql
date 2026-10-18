-- Rank-change alerts (v1.1, user 2026-10-18; decision 89).
-- Run once in the Supabase SQL editor, staging first, after 2026-10-17-rigging-and-announcements.sql.
-- Safe to run again. pg_cron must be on (Database → Extensions), as for practice reminders.
--
-- Every Monday at 08:00 (UK time) each rower who rowed last week (Monday to Sunday) and whose place
-- on the club's weekly metres board moved gets one alert: "You finished 3rd of 12 senior men last
-- week, up 2 places." Their board is the one Rankings opens on: their own gender and level in their
-- club (the whole club when they haven't given a gender), counting only metres on the leaderboards,
-- erg only. Up or down both count; no alert when their place didn't change or they didn't row, or
-- when they're the only one in their group. At most one a week. Settings → Notifications → Rank
-- changes (on unless turned off).

begin;

alter table notification_settings add column if not exists rank_changes boolean not null default true;

-- One rower's week on their board: what the alert says. Kept so the alert can be composed, and so
-- each rower is told at most once a week.
create table if not exists rank_changes (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references profiles on delete cascade,
  week_start    date not null,
  rank          int not null check (rank > 0),
  previous_rank int check (previous_rank > 0),
  group_size    int not null check (group_size > 1),
  group_label   text not null,
  metres        int not null check (metres > 0),
  created_at    timestamptz not null default now(),
  unique (user_id, week_start)
);
alter table rank_changes enable row level security;
drop policy if exists read_own on rank_changes;
create policy read_own on rank_changes for select to authenticated using (user_id = auth.uid());

do $$
begin
  alter table notifications add column if not exists rank_change_id uuid references rank_changes on delete cascade;
  alter table notifications drop constraint if exists notifications_kind_check;
  alter table notifications add constraint notifications_kind_check
    check (kind in ('comment', 'reply', 'pb', 'club_post', 'club_invite', 'new_workout',
                    'new_practice', 'practice_changed', 'practice_cancelled', 'practice_reminder', 'new_event',
                    'boat_seat', 'announcement', 'rank_change'));
end $$;

-- Every rower's place on their own weekly metres board for the week starting p_week (a Monday):
-- metres on the leaderboards from p_week to the Sunday, ranked within their club and group, most
-- first (ties: the earlier account first). Only rowers with metres that week are ranked. Internal.
create or replace function weekly_ranks(p_week date)
returns table (user_id uuid, rank int, group_size int, group_label text, metres int)
language sql stable security definer set search_path = public as $$
  with totals as (
    select p.id, p.club_id, p.gender, p.category, p.created_at,
           coalesce(sum(d.ranked_erg_distance_m), 0)::int as metres
    from profiles p
    left join daily_totals d on d.user_id = p.id and d.day >= p_week and d.day < p_week + 7
    where p.club_id is not null and p.is_rower
    group by p.id
  )
  select u.id,
         (select count(*) from totals o
          where o.club_id = u.club_id and o.metres > 0
            and (u.gender is null or (o.gender = u.gender and o.category = u.category))
            and (o.metres > u.metres or (o.metres = u.metres and (o.created_at, o.id) < (u.created_at, u.id))))::int + 1,
         (select count(*) from totals o
          where o.club_id = u.club_id and o.metres > 0
            and (u.gender is null or (o.gender = u.gender and o.category = u.category)))::int,
         case
           when u.gender is null then 'rowers in your club'
           else u.category::text || ' ' || case u.gender when 'M' then 'men' else 'women' end
         end,
         u.metres
  from totals u
  where u.metres > 0
$$;

-- Monday, 08:00 UK time: last week's places against the week before's; one alert to each rower whose
-- place moved (or who's on the board after a week off). Runs every hour on Mondays and acts once.
-- To try it on another day (testing): select queue_rank_change_alerts(true); — still once a week each.
drop function if exists queue_rank_change_alerts();
create or replace function queue_rank_change_alerts(p_now boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_local timestamp := now() at time zone 'Europe/London';
  v_this_monday date := (v_local::date - (extract(isodow from v_local)::int - 1));
  v_last date := v_this_monday - 7;
begin
  if not p_now and (extract(isodow from v_local) <> 1 or extract(hour from v_local) <> 8) then return; end if;

  with last_week as (select * from weekly_ranks(v_last)),
       week_before as (select * from weekly_ranks(v_last - 7)),
       moved as (
         insert into rank_changes (user_id, week_start, rank, previous_rank, group_size, group_label, metres)
         select l.user_id, v_last, l.rank, b.rank, l.group_size, l.group_label, l.metres
         from last_week l
         left join week_before b on b.user_id = l.user_id
         left join notification_settings ns on ns.user_id = l.user_id
         where l.group_size > 1
           and b.rank is distinct from l.rank
           and coalesce(ns.rank_changes, true)
         on conflict (user_id, week_start) do nothing
         returning id, user_id
       )
  insert into notifications (recipient_id, actor_id, kind, rank_change_id)
  select m.user_id, m.user_id, 'rank_change', m.id from moved m;
end $$;

revoke all on function weekly_ranks(date) from public, anon, authenticated;
revoke all on function queue_rank_change_alerts(boolean) from public, anon, authenticated;

commit;

-- The API sees the new column straight away.
notify pgrst, 'reload schema';

-- MARK: - The weekly job (outside the transaction: pg_cron runs on its own)
create extension if not exists pg_cron;
select cron.unschedule(jobid) from cron.job where jobname = 'rank-change-alerts';
select cron.schedule('rank-change-alerts', '5 * * * 1', 'select public.queue_rank_change_alerts()');
