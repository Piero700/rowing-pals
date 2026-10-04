-- Club tests (decision 28). Run once in the Supabase SQL editor, staging first, after
-- docs/migrations/2026-09-30-clubs.sql. Safe to run again.
--
-- A club's admins and up add their own tests — a distance (750m, 3k) or a whole number of
-- minutes (20min) — next to the nine standard ones. Every member sees them under Rankings →
-- Test results and can post a result to them, which goes on that test's leaderboard.
--
-- Results live in `test_results` like any other, with `distance_key` = 'club:<test id>'. Every
-- other reader (profile PBs, club rankings) only looks for the nine standard keys, so a club
-- result never shows up there. The database checks each club result: the test exists, the
-- rower is in that club, and the piece is the test's distance (or its time, within the same
-- small finish-line tolerance the app allows).

-- MARK: - Table

create table if not exists club_tests (
  id          uuid primary key default gen_random_uuid(),
  -- The only link to another table: a second clubs↔profiles route would make every
  -- `clubs(name)` embed from profiles ambiguous.
  club_id     uuid not null references clubs on delete cascade,
  label       text not null,
  distance_m  int check (distance_m between 100 and 100000),
  duration_ms int check (duration_ms between 60000 and 7200000 and duration_ms % 60000 = 0),
  created_at  timestamptz not null default now(),
  constraint club_tests_one_target check ((distance_m is null) <> (duration_ms is null))
);
create unique index if not exists club_tests_unique_label on club_tests (club_id, lower(label));

alter table club_tests enable row level security;
-- A test's name and target aren't private; a follower reading a clubmate's post sees it too.
-- No write policies: tests change only through the functions below.
drop policy if exists read_all on club_tests;
create policy read_all on club_tests for select to authenticated using (true);

-- MARK: - Naming

-- "750m", "3k", "20min" — the same style as the standard tests' tiles. The app shows the
-- same rule while the admin types (`ClubTest.label`).
create or replace function club_test_label(p_distance_m int, p_duration_ms int)
returns text
language sql immutable as $$
  select case
    when p_distance_m is not null then
      case when p_distance_m % 1000 = 0 then (p_distance_m / 1000)::text || 'k'
           else p_distance_m::text || 'm' end
    else (p_duration_ms / 60000)::text || 'min'
  end;
$$;

-- MARK: - Adding and deleting (admins and up)

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
     and (p_duration_ms % 60000 <> 0 or p_duration_ms not between 60000 and 7200000) then
    raise exception 'A timed test must be a whole number of minutes, from 1 to 120.';
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

create or replace function delete_club_test(p_test uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from club_tests where id = p_test;
  if v_club is null then raise exception 'That test no longer exists.'; end if;
  if not is_club_manager(v_club, 'admin') then
    raise exception 'Only club admins and up can delete a test.';
  end if;
  delete from club_tests where id = p_test;
end $$;

-- A deleted test takes its results with it — whether deleted on its own or with its club.
create or replace function club_tests_delete_results()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from test_results where distance_key = 'club:' || old.id;
  return old;
end $$;

drop trigger if exists club_tests_delete_results on club_tests;
create trigger club_tests_delete_results after delete on club_tests
  for each row execute function club_tests_delete_results();

-- MARK: - Checking each club result

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
  if v_test.duration_ms is not null
     and abs(new.time_ms - v_test.duration_ms) > greatest(2000, v_test.duration_ms / 100) then
    raise exception 'A % test must be % long.', v_test.label, v_test.label;
  end if;
  return new;
end $$;

drop trigger if exists test_results_check_club_test on test_results;
create trigger test_results_check_club_test before insert or update on test_results
  for each row execute function test_results_check_club_test();

-- MARK: - Permissions

revoke all on function create_club_test(int, int) from public, anon;
grant execute on function create_club_test(int, int) to authenticated;
revoke all on function delete_club_test(uuid) from public, anon;
grant execute on function delete_club_test(uuid) to authenticated;
