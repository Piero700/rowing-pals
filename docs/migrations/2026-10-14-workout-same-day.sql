-- A set workout is for its own day, and is posted for once (decision 57). Run once in the
-- Supabase SQL editor, staging first. Safe to run again.
--
-- Until now a session could be linked to any workout set for the rower, on any day, as many
-- times as they liked. Now, as well as being set for them, the session must be from the
-- workout's own day (sessions.session_date is the rower's local day), and the rower mustn't
-- have posted for that workout already. The app already hides such workouts; this is the
-- database refusing them too. Sessions linked before today are left as they are.

begin;

create or replace function sessions_check_workout()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.workout_id is not null
     and (tg_op = 'INSERT' or new.workout_id is distinct from old.workout_id)
     and auth.uid() is not null then
    if not (new.user_id = auth.uid() and auth.uid() in (select workout_audience(new.workout_id))) then
      raise exception 'That workout isn''t set for you.';
    end if;
    if new.session_date is distinct from (select workout_date from coach_workouts where id = new.workout_id) then
      raise exception 'That workout was for another day.';
    end if;
    if exists (
      select 1 from sessions s
      where s.workout_id = new.workout_id and s.user_id = new.user_id and s.id is distinct from new.id
    ) then
      raise exception 'You''ve already posted for that workout.';
    end if;
  end if;
  return new;
end $$;

-- (The trigger sessions_before_write_check_workout from the coaching migration already calls this
-- function; replacing the function is enough.)

commit;
