-- Deleting your own posts (decision 63, user 2026-10-15). Run once in the Supabase SQL editor,
-- staging first, BEFORE installing the build that needs it (new posts write `is_ranked`).
-- Safe to run again.
--
-- A session row already takes its pieces, test results, extra photos, reactions, comments and
-- notifications with it (`on delete cascade`). What it doesn't take is the day's running total
-- in `daily_totals`, which the app adds to when it posts — so deleting goes through
-- `delete_session`, which takes the session back off that day, then deletes it, and returns the
-- photo paths for the app to remove from Storage.

begin;

-- Whether a post counted on the leaderboards ("Include on leaderboards", never a manual entry),
-- so deleting it takes the right metres off. Posts from before this can't say; they're taken
-- as ranked when they had a monitor photo, which is what the app's default did.
alter table sessions add column if not exists is_ranked boolean;
update sessions s
set is_ranked = exists (
  select 1 from segments g where g.session_id = s.id and g.monitor_photo_path is not null
)
where is_ranked is null;

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

  ranked_m := case when coalesce(s.is_ranked, false) then s.total_distance_m else 0 end;
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

-- Your own photo files can be removed from Storage (they live under <your id>/ in both buckets).
drop policy if exists delete_own_photos on storage.objects;
create policy delete_own_photos on storage.objects for delete to authenticated
  using (
    bucket_id in ('monitors', 'selfies')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

commit;
