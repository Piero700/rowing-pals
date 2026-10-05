-- Seconds tests and profile pictures (decisions 28 and 29). Run once in the Supabase SQL editor,
-- staging first, after docs/migrations/2026-10-04-club-tests.sql. Safe to run again.
--
-- 1. A club test can be a time in seconds (30s, 90s), not only whole minutes. A time that is a
--    whole number of minutes is still named in minutes, so 120 seconds and 2min are one test.
--    Short tests get a tighter finish tolerance: 2 s or 1%, whichever is bigger, but at most 5%
--    of the test (1.5 s on a 30s test). Every test of 40 s and up is unchanged.
-- 2. Profile pictures live in a new private `avatars` bucket at <user id>/<file>.jpg, the path
--    kept in `profiles.avatar_path` (already a column). A rower can only write their own
--    folder; a picture is seen under the same rule as workout photos (`can_view_user`), so a
--    private account's picture shows only to its approved followers.

-- MARK: - 1. Seconds tests

alter table club_tests drop constraint if exists club_tests_duration_ms_check;
alter table club_tests add constraint club_tests_duration_ms_check
  check (duration_ms between 10000 and 7200000 and duration_ms % 1000 = 0);

create or replace function club_test_label(p_distance_m int, p_duration_ms int)
returns text
language sql immutable as $$
  select case
    when p_distance_m is not null then
      case when p_distance_m % 1000 = 0 then (p_distance_m / 1000)::text || 'k'
           else p_distance_m::text || 'm' end
    when p_duration_ms % 60000 = 0 then (p_duration_ms / 60000)::text || 'min'
    else (p_duration_ms / 1000)::text || 's'
  end;
$$;

create or replace function create_club_test(p_distance_m int, p_duration_ms int)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_label text;
  v_id uuid;
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_manager(v_club, 'admin') then
    raise exception 'Only club admins and up can add a test.';
  end if;
  if (p_distance_m is null) = (p_duration_ms is null) then
    raise exception 'Choose a distance or a time.';
  end if;
  if p_distance_m is not null and p_distance_m not between 100 and 100000 then
    raise exception 'A distance test must be between 100m and 100,000m.';
  end if;
  if p_duration_ms is not null
     and (p_duration_ms % 1000 <> 0 or p_duration_ms not between 10000 and 7200000) then
    raise exception 'A timed test must be from 10 seconds to 120 minutes.';
  end if;
  if p_distance_m in (500, 1000, 2000, 5000, 6000, 10000)
     or p_duration_ms in (4 * 60000, 30 * 60000, 60 * 60000) then
    raise exception 'That''s already a standard test.';
  end if;

  v_label := club_test_label(p_distance_m, p_duration_ms);
  begin
    insert into club_tests (club_id, label, distance_m, duration_ms)
    values (v_club, v_label, p_distance_m, p_duration_ms)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'Your club already has a % test.', v_label;
  end;
  return v_id;
end $$;

create or replace function test_results_check_club_test()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_test club_tests%rowtype;
begin
  if new.distance_key not like 'club:%' then return new; end if;

  begin
    select * into v_test from club_tests where id = substring(new.distance_key from 6)::uuid;
  exception when invalid_text_representation then
    raise exception 'Unknown club test.';
  end;
  if not found then raise exception 'Unknown club test.'; end if;

  if not exists (select 1 from profiles where id = new.user_id and club_id = v_test.club_id) then
    raise exception 'Only members of the club can post to its tests.';
  end if;
  if v_test.distance_m is not null and new.distance_m <> v_test.distance_m then
    raise exception 'A % test must be exactly %m.', v_test.label, v_test.distance_m;
  end if;
  -- Same rule as the app's StandardTest.finishTolerance.
  if v_test.duration_ms is not null
     and abs(new.time_ms - v_test.duration_ms)
         > greatest(least(2000, v_test.duration_ms / 20), v_test.duration_ms / 100) then
    raise exception 'A % test must be % long.', v_test.label, v_test.label;
  end if;
  return new;
end $$;

revoke all on function create_club_test(int, int) from public, anon;
grant execute on function create_club_test(int, int) to authenticated;

-- MARK: - 2. Profile pictures

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

drop policy if exists avatars_read_visible on storage.objects;
create policy avatars_read_visible on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and can_view_user(((storage.foldername(name))[1])::uuid));

drop policy if exists avatars_own_folder_insert on storage.objects;
create policy avatars_own_folder_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_own_folder_delete on storage.objects;
create policy avatars_own_folder_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
