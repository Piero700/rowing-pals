-- ⚠️  DELETES EVERY CLUB (decision 98), so real owners can create theirs and pick the names.
-- Run by hand in the Supabase SQL editor — Staging first, then Production when you're sure.
-- It cannot be undone. Take a backup first (Database → Backups) if you might want anything back.
--
-- Step-by-step instructions: docs/testing/clubs-guidance-selfie.md, "Deleting every club".
--
-- WHAT IT DELETES, for every club:
--   * the club itself (name, description, location, join policy, focus, week start);
--   * every MEMBERSHIP: every rower and coach is taken out of their club; their role goes back
--     to member and nobody is a coach any more;
--   * join requests, invitations and invite codes;
--   * squads and who's in them;
--   * club tests (custom test tiles; rowers' results on them stay on their own profiles);
--   * set workouts, their attendance, coach notepads and notepad scores;
--   * practices, availability answers, attendance registers, events, terms;
--   * saved boats, water sessions and their crews;
--   * announcements, challenges, erg events;
--   * club-related notifications (join requests, workouts, practices, announcements…);
--   * verification applications (if the verified-clubs migration has run).
--
-- WHAT IT KEEPS: every account, profile, post (session), photo, comment, reaction, follow, PB and
-- test result. A post that was linked to a coach's workout or an erg event just loses that link.
-- Nobody is sent back to onboarding: after this everyone is simply "No club yet" and can find,
-- join or create one from Profile → Your crew.

begin;

-- Memberships can only change while this flag is on (the clubs trigger, 2026-09-30-clubs.sql).
select set_config('rp.club_change', 'on', true);

update profiles
set club_id = null, club_role = 'member', is_coach = false, club_joined_at = null
where club_id is not null or club_role <> 'member' or is_coach;

-- Everything that belongs to a club goes with it (each table's club_id is ON DELETE CASCADE).
delete from clubs;

commit;

-- Check: both should be 0.
select (select count(*) from clubs) as clubs_left,
       (select count(*) from profiles where club_id is not null) as rowers_still_in_a_club;
