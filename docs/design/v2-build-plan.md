# v2 redesign — build plan and status

Updated 2026-09-23 from the git log of branch `worktree-t21-redesign-continue` and a file audit.
Decisions live in `v2-decisions.md` (they win). Screens/components live in
`rowing-pals-redesign-handoff-v2.md`. Rhythm for every phase: build, independently re-verify against
the prototype's raw CSS/SVG, fix, then report. Never trade fidelity for speed.

## Done (branch `worktree-t21-redesign-continue`, not yet merged to `main`)

| Phase | What |
|---|---|
| A | 4-role palette; Metres+Tests merged into one Rankings tab; custom split floating tab bar |
| B | Split/watts pace toggle; distance toggle — **narrowed to Volume leaderboard only** per decision 3 (uncommitted at time of writing) |
| C | Profile: 4-up stats, Overview / PBs / Posts; streak badges on Feed and Rankings avatars |
| D | Rankings Filters sheet + rank-hero card; 4-corner configurable capture inset; photo-first workout-hero `PostDetailView`; PB history screen with scrubbable chart (prediction card is a marked placeholder); app icon artwork |

## Remaining, in proposed order

Each item says what must be checked first, because the audit only proves what files exist, not
that they match the prototype.

1. **Branch hygiene (do first).** Commit the km narrowing, fast-forward `t21-redesign-foundation`
   or work only on `worktree-t21-redesign-continue`, merge to `main` once verified. Two branches
   currently carry the redesign; keep one.
2. **E — Private accounts + follow requests. BUILT (branch `t22-private-accounts`), not yet
   exercised against a database.** Decisions: private means only approved followers see anything —
   no clubmate access, and a private account drops off leaderboards for non-followers.
   - Database: `docs/migrations/2026-09-23-private-accounts.sql` (also folded into
     `docs/schema.sql`): `profiles.is_private`, `follows.status`, `can_view_user()` /
     `can_view_session()`, visibility-aware read policies on sessions, segments, test results,
     daily totals, reactions and comments, and triggers so a client can never choose its own follow
     status. **Must be run in Supabase (staging first) before the app works.** Photo buckets need
     a separate manual storage policy (see the end of the migration file).
   - App: `FollowService`, `AppRoute` + `navigate` environment action + `RouteHost`, other-rower
     profile (`ProfileView(viewing:)`, with the private-card), Followers / Following / Find rowers
     (`Features/People`), Follow requests screen, `FollowButton` (Follow / Follow back / Requested /
     Following), Privacy sheet in Settings, avatar taps on feed cards and the post-detail pill,
     Following scope limited to accepted follows.
   - **Database rules verified 2026-09-24** against staging with the SQL tests in
     `docs/testing/phase-e-private-accounts.md` Part 2 (stranger sees nothing; can't self-approve;
     can't choose status; approved follower sees data). The in-app checks (Part 1) are still to do.
   - Still to do in E: the "Overall rankings" mini-card on another rower's profile (volume / 2k / 5k
     rank); a follow-request badge on the Profile tab; testing against a real database, including
     two accounts (one private) to prove the privacy rules; unit tests for `FollowService` state
     logic.
3. **F — Review session.** Main-workout label (UT2/UT1/Threshold/Intervals/Test/Recovery); read-only
   auto-computed average split; stroke-rate inline Confirm; session-type dropdown with 2k/5k
   validation that updates PB and the test board; extra-photo strip; "Enter session manually"
   from Capture. Verify against `ReviewSheetView` first — some may already exist.
4. **G — Clubs.** Create club, join policy (open / approval / invite), roles
   (owner / co-owner / admin / member), join requests, owner-only management, onboarding policy
   tags and "Join request pending". Needs schema (roles, policy, requests). Existing base:
   `Features/Onboarding/ClubSearchView`.
5. **H — Settings overhaul.** App-icon picker (alternate icons; artwork already added), notification
   toggles, privacy row (needs E), account section. **No CSV export** (decision 4). Quiet hours and
   "Who can comment" are placeholders: confirm before building.
6. **I — Custom tests.** "+ Add test" tile and form on Test results; test-detail with the shared
   filter sheet.
7. **J — Feed extras.** Full-screen comments thread (`comments` table already exists), 12-emoji
   picker, share-workout preview.
8. **K — Prediction cards.** Wire in the user's own algorithm once supplied. Until then only the
   placeholder shown today. Do not write an algorithm.
9. **L — Polish and release.** Tab bar (user: "still not there" — get concrete detail before
   changing it), light mode and Increase Contrast pass, full screen-by-screen comparison against the
   prototype, then task 19 (TestFlight).

## Waiting on the user

- The prediction algorithm (phase K).
- Concrete description of what is still wrong with the tab bar (phase L).
- Go-ahead on placeholders: quiet hours, "Who can comment".
