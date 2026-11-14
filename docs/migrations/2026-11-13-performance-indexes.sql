-- Performance indexes (2026-11-13). Run once in the Supabase SQL editor, staging first. Safe to run
-- again. Run on staging 2026-11-14 (dry run rolled back first); not yet on production. Changes no data and no behaviour: each index serves a lookup the app already makes, which
-- today reads the whole table. On staging, pg_stat_user_tables showed profiles scanned whole
-- 345,726 times (against 47,561 index scans) and test_results 16,438 times (against 992).
--
-- On a project with real traffic, run each statement on its own with CONCURRENTLY added
-- (`create index concurrently if not exists …`) so writes aren't held while it builds; CONCURRENTLY
-- can't run inside begin/commit, which is why this file has none.

-- Everyone in a club: clubmates (ViewerContext), the members list (CalendarService.members), the
-- coach's Rowers list, club ranks, challenge standings, Rankings.
create index if not exists profiles_club_id_idx on profiles (club_id);

-- Someone's followers and follow requests (FollowService), follower counts on Profile.
-- The primary key (follower_id, followee_id) only serves "who I follow".
create index if not exists follows_followee_status_idx on follows (followee_id, status);

-- A rower's test results: Profile's personal bests, PB history, Rankings' Tests, predictions'
-- test pieces, the coach's 2k column. The existing index leads with distance_key for leaderboards.
create index if not exists test_results_user_distance_idx on test_results (user_id, distance_key);

-- A post's test results (the workout's result banner), and deleting a post, whose cascade
-- otherwise reads all of test_results.
create index if not exists test_results_session_idx on test_results (session_id);

-- The posts rowed for a coach's workout (workout results, the notepad's posted splits).
create index if not exists sessions_workout_idx on sessions (workout_id) where workout_id is not null;

-- A practice's register history (CalendarService.markLog), newest change last.
create index if not exists attendance_mark_log_practice_idx on attendance_mark_log (practice_id, set_at);
