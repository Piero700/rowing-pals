# Coaching and the v4 canvas — build plan

Adopted 2026-10-05 (decisions 34–38 in `v2-decisions.md`). Design source: the canvas
https://claude.ai/artifact/42YP5UcaQKWnfQdERRgLcc, saved at `docs/design/v4/` (`*.dc.html`,
`canvas.json`; open a file in a browser or read its markup for exact values). The canvas note says
the coaching screens were "built from the brief's decisions 1–6"; that brief hasn't been shared —
if it turns up, its decisions go into `v2-decisions.md`.

Each phase: build, check on the simulator against its artboards, write a test checklist under
`docs/testing/`, then the user confirms and it's merged. Server changes ship as one migration per
phase in `docs/migrations/`, run on staging first.

## Phase C1 — Existing screens catch up with the canvas
Artboards: `RankingsVolume`, `RankingsTests`, `RankingsFilters`, `Settings`, `SettingsProfile`,
`SettingsPrivacy`, `PostDetail`.
- Rankings open on your own group; Volume rank card wording; Test results "Best in your group";
  Filters' Source (Volume only). (Decision 37.)
- Settings: Match iPhone; remove Quiet hours (app and server); Privacy Policy link. The two new
  alert switches arrive with the features they control (C4, C5). (Decision 36.)
- Edit profile: Weekly target (km). Account type waits for C2.
- Workout screen: drop "Photo-verified". (Decision 38.)

## Phase C2 — Coaches, coach-only accounts and privacy
Artboards: `CoachMakeCoach`, `CoachOnboarding`, `CoachJoinNotice`, `CoachCrew`, `CoachOnlyFeed`,
`SettingsProfile` (Account type), `SettingsPrivacy`.
- Server: a coach flag per club member; who may grant it; coaches read every member's sessions,
  photos, tests, daily totals and `athlete_private` (extends `can_view_session()` of decision 33
  and the private-account rule); coach-only accounts excluded from every leaderboard.
- App: Make coach; "I row / I'm a coach" at onboarding and in Edit profile; coach-only accounts
  have no Log button and no rankings; the join notice; coaches listed in Your crew with a way into
  Coaching.

## Phase C3 — Coaching: rowers and squads
Artboards: `CoachRowers`, `CoachSortSheet`, `CoachRower`, `CoachSquads`, `CoachSquadEdit`.
- Rowers tab: week volume against weekly target, sessions, attendance (from C5; hidden until
  then), 2k PB, Pace Engine prediction, flags (no session in N days; the engine's mis-tag and
  `elevated_recent_effort`). Squad filter and sort.
- One rower: age, bodyweight, private-account badge, flag explanation, 8-week volume, zone mix,
  effort trend, tests with watts and W/kg, attendance grid (C5), posts.
- Squads: list, create, edit members, delete.

## Phase C4 — Set workouts
Artboards: `CoachWorkouts`, `CoachWorkoutNew`, `CoachWorkoutResults`, `RowerFeedCoaching`,
`RowerLogCoaching`.
- Coach creates a workout (title, date, optional time, description, target zone, pieces with
  reps/rest/rate/split targets, test day, whole club / squads / rowers).
- Rowers: "New workout from your coach" alert (Settings switch), Today's workout card on the feed
  with "Log it", and linking a logged session to the workout.
- Results: done / partly / not yet, each piece's split against target.

## Phase C5 — Practices and attendance
Artboards: `CoachPractices`, `CoachPracticeNew`, `CoachPracticeRegister`, `CoachAttendance`,
`RowerPractice`, the practice card in `RowerFeedCoaching`.
- Practices with place, time, squads, weekly repeats until a date, edit/cancel one or the series
  (members notified).
- Rowers answer Going / Can't make it (reason seen by coaches only) and check in from 30 minutes
  before; reminders 2 hours before (Settings switch; needs a scheduled server job).
- Register: present / late / absent / excused, suggested ticks from sessions posted that day,
  the coach's mark always wins. Attendance totals by term (editable dates), squad and rower.

## Questions to settle at the start of each phase
- C2: who can make someone a coach (owner and co-owners?); can a coach also row in the same club
  (the canvas shows "Co-owner · Coach · Novice", so yes); what a coach-only account sees on Feed.
- C3: thresholds for "no session in N days" and "behind target".
- C4: what "partly" means for a linked session; whether a test-day workout posts to the test's
  leaderboard automatically.
- C5: what "check in" proves (a tap during the window, no location); term dates per club.
