-- Coach notepad, phase NP3 (user, 2026-11-05; decision 96; docs/design/coach-notepad-build-plan.md).
-- Run once in the Supabase SQL editor, after 2026-11-05-coach-notepad.sql. Safe to run again.
-- Run it on every project a build points at before that build is used: posting writes the new
-- segments column, and the notepad reads it.
--
-- What it does:
--   1. segments.splits_500_ms: the split of every row the monitor shows under a continuous piece
--      (a 2k's four 500m splits), kept when a rower posts, so a coach's test notepad can show them.
--   2. save_notepad_score takes the 500m splits too (a test scanned off the monitor).
--   3. Fix: a workout set with only a title ("4 x 500m", no pieces) takes scores for every rep the
--      app reads from the title. The server used to count reps from the pieces only, so it refused
--      every rep after the first on such a workout.

begin;

-- MARK: - 1. Splits on posted segments

alter table segments add column if not exists splits_500_ms int[];

alter table segments drop constraint if exists segments_splits_500_ms_valid;
alter table segments add constraint segments_splits_500_ms_valid check (
  splits_500_ms is null
  or (cardinality(splits_500_ms) between 1 and 100
      and 30000 <= all (splits_500_ms) and 600000 >= all (splits_500_ms))
);

-- MARK: - 2 and 3. Saving a score

alter table coach_notepad_scores drop constraint if exists coach_notepad_scores_splits_valid;
alter table coach_notepad_scores add constraint coach_notepad_scores_splits_valid check (
  splits_500_ms is null
  or (cardinality(splits_500_ms) between 1 and 100
      and 30000 <= all (splits_500_ms) and 600000 >= all (splits_500_ms))
);

-- The old nine-argument version goes; the new one has the splits as a tenth.
drop function if exists save_notepad_score(uuid, uuid, int, int, int, int, int, boolean, text);

create or replace function save_notepad_score(
  p_workout uuid, p_user uuid, p_piece int, p_split_ms int, p_time_ms int, p_distance_m int,
  p_rate int, p_sat_out boolean, p_source text, p_splits_500_ms int[] default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid := notepad_club(p_workout);
  v_has_pieces boolean;
  v_reps int;
begin
  if not exists (select 1 from profiles where id = p_user and club_id = v_club) then
    raise exception 'That rower isn''t in your club.';
  end if;
  select coalesce(jsonb_array_length(w.pieces), 0) > 0 into v_has_pieces from coach_workouts w where w.id = p_workout;
  if coalesce(v_has_pieces, false) then
    select greatest(1, coalesce(sum(greatest(1, coalesce((p->>'reps')::int, 1))), 0))::int into v_reps
    from coach_workouts w, jsonb_array_elements(w.pieces) p where w.id = p_workout;
  else
    -- No pieces: the app takes the reps from the title. The table's own limit (200) still holds.
    v_reps := 200;
  end if;
  if p_piece is null or p_piece < 0 or p_piece >= coalesce(v_reps, 1) then raise exception 'That piece isn''t in this workout.'; end if;
  if not coalesce(p_sat_out, false) and (p_split_ms is null or p_split_ms not between 30000 and 600000) then
    raise exception 'Type a split between 0:30.0 and 10:00.0, or mark them as sat out.';
  end if;

  insert into coach_notepad_scores (workout_id, user_id, piece_index, club_id, split_ms, time_ms, distance_m,
                                    rate, sat_out, splits_500_ms, source, updated_by, updated_at)
  values (p_workout, p_user, p_piece, v_club,
          case when coalesce(p_sat_out, false) then null else p_split_ms end,
          case when coalesce(p_sat_out, false) then null else p_time_ms end,
          case when coalesce(p_sat_out, false) then null else p_distance_m end,
          case when coalesce(p_sat_out, false) then null else p_rate end,
          coalesce(p_sat_out, false),
          case when coalesce(p_sat_out, false) then null else p_splits_500_ms end,
          coalesce(p_source, 'typed'), auth.uid(), now())
  on conflict (workout_id, user_id, piece_index) do update
    set split_ms = excluded.split_ms, time_ms = excluded.time_ms, distance_m = excluded.distance_m,
        rate = excluded.rate, sat_out = excluded.sat_out, splits_500_ms = excluded.splits_500_ms,
        source = excluded.source, updated_by = excluded.updated_by, updated_at = excluded.updated_at;
end $$;

grant execute on function save_notepad_score(uuid, uuid, int, int, int, int, int, boolean, text, int[]) to authenticated;

commit;
