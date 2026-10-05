# Coaching and the v4 canvas — build plan

Adopted 2026-10-05 (decisions 34–38 in `v2-decisions.md`). Design source: the canvas
https://claude.ai/artifact/42YP5UcaQKWnfQdERRgLcc, saved at `docs/design/v4/` (`*.dc.html`,
`canvas.json`; open a file in a browser or read its markup for exact values). The canvas note says
the coaching screens were "built from the brief's decisions 1–6"; that brief hasn't been shared —
if it turns up, its decisions go into `v2-decisions.md`.

Each phase: build, check on the simulator against its artboards, write a test checklist under
`docs/testing/`, then the user confirms and it's merged. Server changes ship as one migration per
phase in `docs/migrations/`, run on staging first.

## Catch-up — Existing screens match the canvas (first) — BUILT, branch `t36-canvas-catch-up`
Artboards: `RankingsVolume`, `RankingsTests`, `RankingsFilters`, `Settings`, `PostDetail`.
- Rankings open on your own group; Volume rank card wording; Test results "Best in your group";
  Filters' Source (Volume only). (Decision 37.)
- Settings: Match iPhone; remove Quiet hours; Privacy Policy link. (Decision 36.)
  Quiet hours is gone from the app and from `send-push` (redeployed to staging 2026-10-05); its
  `notification_settings` columns stay, unused. The Privacy Policy is an in-app page
  (`DesignSystem/PrivacyPolicyView.swift`) that still needs the user's review, and a public web
  copy before App Store submission. **Phase 1 must update it**: coaches will see age and
  bodyweight (decision 35).
- Workout screen: drop "Photo-verified". (Decision 38.)

## Phase 1 — Coaches, squads, the overview and privacy (brief phase 1) — BUILT, branch `t39-coaching-phase1`
Built 2026-10-05 (decisions 43–47; checklist `docs/testing/coaching-phase1.md`). Waiting on: the
migration run on staging, then the user's phone test before merging. Left for later phases, on
purpose: attendance figures (Rowers list, one rower's page, the sort) and the Workouts /
Practices tabs. Open question for the user: the canvas's "±4s" on predictions — the engine gives a
confidence band, shown as "· High" for now (decision 45).
Artboards: `CoachMakeCoach`, `CoachOnboarding`, `CoachJoinNotice`, `CoachCrew`, `CoachOnlyFeed`,
`SettingsProfile`, `SettingsPrivacy`, `CoachRowers`, `CoachSortSheet`, `CoachRower`, `CoachSquads`,
`CoachSquadEdit`.
- `docs/migrations/2026-10-05-coaching.sql`: coach flag, non-rowing flag, squads and members,
  workouts and assignments, `sessions.workout_id`, practices, responses and marks (`set_by`,
  `set_at`), term dates; security-definer RPCs for every write; `is_club_coach()`; RLS on every
  table; coaches read their members (`can_view_user`, a read rule beside `can_view_session`, the
  photo policy, `athlete_private`) — read-only (decision 40).
- Make coach (owner, co-owners); "I row / I'm a coach" at onboarding and in Edit profile; weekly
  target; non-rowing coaches: no Log button, no gender/level, off every board and Crewmates;
  Coaches section in Your crew; join notice; Privacy sheet wording.
- Coaching entry (Your crew, Profile → Club); Rowers list (week metres vs target, sessions, latest
  test and PBs, predicted 2k and band, term attendance once Phase 3 lands), sort and squad filter,
  flags (`elevated_recent_effort`, `tier_disagreement`, 10+ days without a session); one rower
  (volume chart, zone mix, effort trend, tests with W/kg, attendance history, posts, age and
  bodyweight); squads (list, create, rename, members, delete).

## Phase 2 — Set workouts (brief phase 2)
Artboards: `CoachWorkouts`, `CoachWorkoutNew`, `CoachWorkoutResults`, `RowerFeedCoaching`,
`RowerLogCoaching`.
- Create (title, date, optional time, description, zone, optional pieces with reps/rest/rate/
  split, optional test day → a standard or club test; whole club / squads / rowers).
- Rowers: Today's workout on Feed and Log; posting links the session (default on); push kind
  "New workout from your coach" with its Settings switch.
- Coach: done / partly / not yet per rower, actual splits against targets.

## Phase 3 — Attendance (brief phase 3)
Artboards: `CoachPractices`, `CoachPracticeNew`, `CoachPracticeRegister`, `CoachAttendance`,
`RowerPractice`, the practice card in `RowerFeedCoaching`.
- Practices: date, start/end, place, squads; one-off or weekly until a date; edit/cancel one or
  the series (rowers notified).
- Rowers: Going / Can't make it (+ reason, coaches only), check-in on the day.
- Register: fast tick list, suggested ticks from sessions posted that day, coach's mark wins,
  editable later, who/when kept. Totals per rower and squad over a range, default the current
  term, term dates set by coaches. Optional reminder push with its Settings switch.

## Questions to settle at the start of each phase
- ~~Phase 1: what "behind target" means mid-week~~ — pro-rata (decision 43).
- Phase 2: what "partly" means for a linked session; whether a test-day workout posts to the
  test's leaderboard automatically.
- Phase 3: what "check in" proves (a tap during the window, no location).

Each phase: new branch; decisions recorded; build plan updated; click-by-click checklist in
`docs/testing/`; unit tests for the rules (who can see what, coach override, squad filters,
completion matching); build, all tests, every new screen checked on the simulator; report what
was tested and what needs a second phone; **no merge until the user has tested on their phone**.
