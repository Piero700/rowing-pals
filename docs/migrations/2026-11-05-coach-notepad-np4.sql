-- Coach notepad, phase NP4 (user, 2026-11-05; decision 96; docs/design/coach-notepad-build-plan.md).
-- Run once in the Supabase SQL editor, after 2026-11-05-coach-notepad-np3.sql. Safe to run again.
--
-- What it adds: my_notepad_scores(p_since), the one way a rower sees anything from a notepad — the
-- scores the club's coaches noted for *them*, for their Feed card (RowerCoachScores). It never
-- returns another rower's scores, or any page's text, tables or Notes. Rowers still can't read the
-- notepad tables themselves.

begin;

create or replace function my_notepad_scores(p_since date)
returns table (
  workout_id uuid, title text, workout_date date, pieces jsonb, test_key text,
  coach_name text, club_name text,
  -- Where the coach put the rower in erg order (1 = first erg); null when not placed.
  erg int,
  piece_index int, split_ms int, sat_out boolean,
  -- The rower's own posted average for the workout, when they posted it with "Link this session".
  posted_avg_split_ms int
)
language sql stable security definer set search_path = public as $$
  select w.id, w.title, w.workout_date, w.pieces, w.test_key,
         coach.display_name, club.name,
         array_position(page.rower_order, auth.uid()),
         s.piece_index, s.split_ms, s.sat_out,
         (select own.avg_split_ms from sessions own
          where own.workout_id = w.id and own.user_id = auth.uid()
          order by own.posted_at desc limit 1)
  from coach_notepad_scores s
  join coach_workouts w on w.id = s.workout_id
  left join coach_notepads page on page.workout_id = w.id
  left join profiles coach on coach.id = w.created_by
  left join clubs club on club.id = w.club_id
  where s.user_id = auth.uid()
    -- Only while they're still in that club.
    and w.club_id = (select me.club_id from profiles me where me.id = auth.uid())
    and w.workout_date >= p_since
  order by w.workout_date desc, s.piece_index;
$$;

revoke all on function my_notepad_scores(date) from public;
grant execute on function my_notepad_scores(date) to authenticated;

commit;
