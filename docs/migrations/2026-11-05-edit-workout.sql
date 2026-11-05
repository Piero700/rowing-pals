-- Editing a set workout (user, 2026-11-05: "there is no way to edit a workout"). Run once in the
-- Supabase SQL editor, on every project a build points at. Safe to run again.
--
-- update_workout: the club's coaches change a workout's title, day, time, notes, zone, test, pieces
-- and who it's for, with the same checks as create_workout. Rowers aren't alerted again. Sessions
-- already linked to it stay linked; a notepad keeps its page and scores.

begin;

create or replace function update_workout(
  p_workout uuid, p_title text, p_date date, p_start_time time, p_description text, p_zone text,
  p_test_key text, p_pieces jsonb, p_audience text, p_squads uuid[], p_rowers uuid[]
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from coach_workouts where id = p_workout;
  if v_club is null then raise exception 'That workout isn''t there any more.'; end if;
  if not is_club_coach(v_club) then raise exception 'Only your club''s coaches can change workouts.'; end if;
  if coalesce(char_length(btrim(p_title)), 0) = 0 then raise exception 'Give the workout a title.'; end if;
  if p_audience not in ('club', 'squads', 'rowers') then raise exception 'Choose who the workout is for.'; end if;
  if jsonb_typeof(coalesce(p_pieces, '[]'::jsonb)) <> 'array' then raise exception 'Pieces must be a list.'; end if;
  if p_test_key is not null
     and p_test_key not in ('500m', '1k', '2k', '5k', '6k', '10k', '4min', '30min', '60min')
     and not exists (select 1 from club_tests ct where ct.club_id = v_club and 'club:' || ct.id::text = p_test_key) then
    raise exception 'That test isn''t one of your club''s tests.';
  end if;

  update coach_workouts
     set title = btrim(p_title), workout_date = p_date, start_time = p_start_time,
         description = nullif(btrim(coalesce(p_description, '')), ''), zone = p_zone,
         test_key = p_test_key, pieces = coalesce(p_pieces, '[]'::jsonb), audience = p_audience
   where id = p_workout;

  delete from coach_workout_targets where workout_id = p_workout;
  if p_audience = 'squads' then
    insert into coach_workout_targets (workout_id, squad_id)
      select p_workout, s.id from squads s where s.id = any(coalesce(p_squads, '{}')) and s.club_id = v_club;
    if not found then raise exception 'Choose at least one squad.'; end if;
  elsif p_audience = 'rowers' then
    insert into coach_workout_targets (workout_id, user_id)
      select p_workout, p.id from profiles p
      where p.id = any(coalesce(p_rowers, '{}')) and p.club_id = v_club and p.is_rower;
    if not found then raise exception 'Choose at least one rower.'; end if;
  end if;
end $$;

revoke all on function update_workout(uuid, text, date, time, text, text, text, jsonb, text, uuid[], uuid[]) from public;
grant execute on function update_workout(uuid, text, date, time, text, text, text, jsonb, text, uuid[], uuid[]) to authenticated;

commit;
