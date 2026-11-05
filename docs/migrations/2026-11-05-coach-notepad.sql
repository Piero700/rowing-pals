-- Coach notepad, phase NP1 (user, 2026-11-05; decision 96; docs/design/coach-notepad-build-plan.md).
-- Run once in the Supabase SQL editor, staging first, after 2026-11-03-mutual-follow-posts.sql.
-- Safe to run again.
--
-- What it adds:
--   1. coach_notepads: one page per set workout — its text and table blocks, its Notes, and the
--      order the coach put the rowers in (erg order).
--   2. coach_notepad_scores: a score the coach typed (or, from NP2, scanned) for one rower's rep.
--   3. save_notepad, save_notepad_score, delete_notepad_score: the only way to write either table.
--
-- Coach-only: every coach in the workout's club reads and edits every page (user, 2026-11-05).
-- Rowers can't read either table. Nothing else in the database reads them, so nothing written here
-- reaches volume, pieces, PBs, predictions, streaks, Wrapped, challenges or any leaderboard.

begin;

-- MARK: - 1. Pages

create table if not exists coach_notepads (
  workout_id  uuid primary key references coach_workouts on delete cascade,
  club_id     uuid not null references clubs on delete cascade,
  -- [{ "id": "<uuid>", "kind": "text", "text": "…" }
  --  { "id": "<uuid>", "kind": "table", "title": "…", "cells": [["Rower", "Technique"], ["", ""]] }]
  -- The Scores table isn't a block: every page has it, above the blocks.
  blocks      jsonb not null default '[]'::jsonb,
  notes       text not null default '',
  -- The rowers in the order the coach put them (erg order); anyone not listed follows, by name.
  rower_order uuid[] not null default '{}',
  updated_by  uuid references profiles on delete set null,
  updated_at  timestamptz not null default now()
);

alter table coach_notepads drop constraint if exists coach_notepads_blocks_array;
alter table coach_notepads add constraint coach_notepads_blocks_array
  check (jsonb_typeof(blocks) = 'array' and jsonb_array_length(blocks) <= 30);
alter table coach_notepads drop constraint if exists coach_notepads_notes_length;
alter table coach_notepads add constraint coach_notepads_notes_length check (char_length(notes) <= 10000);

alter table coach_notepads enable row level security;
drop policy if exists coaches_read on coach_notepads;
create policy coaches_read on coach_notepads for select to authenticated
  using (is_club_coach(club_id));

-- MARK: - 2. Scores

create table if not exists coach_notepad_scores (
  workout_id    uuid not null references coach_workouts on delete cascade,
  user_id       uuid not null references profiles on delete cascade,
  -- The rep, counting every rep of every piece from 0 (3 × 2,000m has reps 0, 1 and 2).
  piece_index   int not null,
  club_id       uuid not null references clubs on delete cascade,
  split_ms      int,
  -- What the coach typed, when it wasn't the split: the time off the monitor (a distance piece)
  -- or the metres (a time piece). The split is always worked out and stored.
  time_ms       int,
  distance_m    int,
  rate          smallint,
  sat_out       boolean not null default false,
  -- A test's 500m splits, when they were scanned (NP3).
  splits_500_ms int[],
  source        text not null default 'typed',
  updated_by    uuid references profiles on delete set null,
  updated_at    timestamptz not null default now(),
  primary key (workout_id, user_id, piece_index)
);

alter table coach_notepad_scores drop constraint if exists coach_notepad_scores_valid;
alter table coach_notepad_scores add constraint coach_notepad_scores_valid check (
  piece_index between 0 and 199
  and source in ('typed', 'scanned')
  and (sat_out or split_ms is not null)
  and (split_ms is null or split_ms between 30000 and 600000)
  and (time_ms is null or time_ms between 1000 and 36000000)
  and (distance_m is null or distance_m between 1 and 100000)
  and (rate is null or rate between 10 and 70)
);

alter table coach_notepad_scores enable row level security;
drop policy if exists coaches_read on coach_notepad_scores;
create policy coaches_read on coach_notepad_scores for select to authenticated
  using (is_club_coach(club_id));

-- MARK: - 3. Writing

-- The workout's club, once the caller is shown to coach it. Internal.
create or replace function notepad_club(p_workout uuid)
returns uuid
language plpgsql stable security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from coach_workouts where id = p_workout;
  if v_club is null then raise exception 'That workout has gone.'; end if;
  if not is_club_coach(v_club) then raise exception 'Only your club''s coaches can use the notepad.'; end if;
  return v_club;
end $$;

-- Saves a page's blocks, Notes and rower order (made on its first save).
create or replace function save_notepad(p_workout uuid, p_blocks jsonb, p_notes text, p_rower_order uuid[])
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid := notepad_club(p_workout);
  v_block jsonb;
  v_row jsonb;
begin
  if p_blocks is null or jsonb_typeof(p_blocks) <> 'array' then raise exception 'The page couldn''t be read.'; end if;
  if jsonb_array_length(p_blocks) > 30 then raise exception 'A page holds up to 30 text boxes and tables.'; end if;
  for v_block in select * from jsonb_array_elements(p_blocks) loop
    if v_block->>'kind' = 'text' then
      if char_length(coalesce(v_block->>'text', '')) > 4000 then raise exception 'A text box holds up to 4,000 characters.'; end if;
    elsif v_block->>'kind' = 'table' then
      if char_length(coalesce(v_block->>'title', '')) > 80 then raise exception 'A table''s name is up to 80 characters.'; end if;
      if jsonb_typeof(v_block->'cells') <> 'array' or jsonb_array_length(v_block->'cells') > 51 then
        raise exception 'A table holds up to 50 rows.';
      end if;
      for v_row in select * from jsonb_array_elements(v_block->'cells') loop
        if jsonb_typeof(v_row) <> 'array' or jsonb_array_length(v_row) > 5 then raise exception 'A table holds up to 5 columns.'; end if;
        if exists (select 1 from jsonb_array_elements_text(v_row) c where char_length(c) > 200) then
          raise exception 'A table box holds up to 200 characters.';
        end if;
      end loop;
    else
      raise exception 'The page couldn''t be read.';
    end if;
  end loop;

  insert into coach_notepads (workout_id, club_id, blocks, notes, rower_order, updated_by, updated_at)
  values (p_workout, v_club, p_blocks, coalesce(p_notes, ''), coalesce(p_rower_order, '{}'), auth.uid(), now())
  on conflict (workout_id) do update
    set blocks = excluded.blocks, notes = excluded.notes, rower_order = excluded.rower_order,
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;
end $$;

-- Saves one rower's score for one rep: a split (with what was typed to get it), or sat out.
create or replace function save_notepad_score(
  p_workout uuid, p_user uuid, p_piece int, p_split_ms int, p_time_ms int, p_distance_m int,
  p_rate int, p_sat_out boolean, p_source text
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid := notepad_club(p_workout);
  v_reps int;
begin
  if not exists (select 1 from profiles where id = p_user and club_id = v_club) then
    raise exception 'That rower isn''t in your club.';
  end if;
  select greatest(1, coalesce(sum(greatest(1, coalesce((p->>'reps')::int, 1))), 0))::int into v_reps
  from coach_workouts w, jsonb_array_elements(w.pieces) p where w.id = p_workout;
  if p_piece is null or p_piece < 0 or p_piece >= coalesce(v_reps, 1) then raise exception 'That piece isn''t in this workout.'; end if;
  if not coalesce(p_sat_out, false) and (p_split_ms is null or p_split_ms not between 30000 and 600000) then
    raise exception 'Type a split between 0:30.0 and 10:00.0, or mark them as sat out.';
  end if;

  insert into coach_notepad_scores (workout_id, user_id, piece_index, club_id, split_ms, time_ms, distance_m,
                                    rate, sat_out, source, updated_by, updated_at)
  values (p_workout, p_user, p_piece, v_club,
          case when coalesce(p_sat_out, false) then null else p_split_ms end,
          case when coalesce(p_sat_out, false) then null else p_time_ms end,
          case when coalesce(p_sat_out, false) then null else p_distance_m end,
          case when coalesce(p_sat_out, false) then null else p_rate end,
          coalesce(p_sat_out, false), coalesce(p_source, 'typed'), auth.uid(), now())
  on conflict (workout_id, user_id, piece_index) do update
    set split_ms = excluded.split_ms, time_ms = excluded.time_ms, distance_m = excluded.distance_m,
        rate = excluded.rate, sat_out = excluded.sat_out, source = excluded.source,
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;
end $$;

-- Takes one score off the page (the box goes back to the rower's own post, or empty).
create or replace function delete_notepad_score(p_workout uuid, p_user uuid, p_piece int)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform notepad_club(p_workout);
  delete from coach_notepad_scores where workout_id = p_workout and user_id = p_user and piece_index = p_piece;
end $$;

revoke all on function notepad_club(uuid) from public;
grant execute on function save_notepad(uuid, jsonb, text, uuid[]) to authenticated;
grant execute on function save_notepad_score(uuid, uuid, int, int, int, int, int, boolean, text) to authenticated;
grant execute on function delete_notepad_score(uuid, uuid, int) to authenticated;

commit;
