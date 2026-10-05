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
2. **E — Private accounts + follow requests. MERGED to `main` 2026-09-24 (database rules verified
   on staging; in-app checks pending).** Decisions: private means only approved followers see anything —
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
3. **F — Review session. BUILT (branch `t23-review-session`); needs the 2026-09-24 migration and
   a real-device check.** Decisions: a manual entry is personal-only (never on leaderboards, never
   a test result, stored `photo_verified = false`).
   - Database: `docs/migrations/2026-09-24-review-session.sql` (also in `docs/schema.sql`):
     `sessions.workout_label`, `daily_totals.ranked_*` (what leaderboards now read),
     `session_photos` (+ RLS). **Run in Supabase, staging first, before running this build.**
   - App: main-workout label dropdown (UT2 / UT1 / Threshold / Intervals / Test / Recovery) shown
     as the Main split's badge in the feed and post detail; average /500m read-only and derived
     from distance and time; stroke rate with an inline Confirm, required before posting and
     cleared by any edit; Session type dropdown (Training + every standard test) with exact-match
     validation, keeping the "this looks like a test" suggestion; "Include on leaderboards"
     switch; extra-photo strip (photo library, up to 6, removable) shown in the post detail
     gallery; "Enter session manually" on Capture; Volume leaderboard reads the ranked columns.
   - Verified: build passes; 21 unit tests in `ReviewSessionTests` pass. NOT yet run on a device
     (the camera path needs a real phone) or against the migrated database.
   - Not done: manual-entry posts show a "MANUAL ENTRY" placeholder where the photo would be —
     confirm that's the look you want.
   - **Step 1 of the 2026-09-25 plan, BUILT on the same branch** (`39ce605`, `dc0c7b1`): one
     "Add photo" (camera or library), automatic monitor/environment detection with corrections,
     lead piece (`segments.is_lead`), new-PB flag (`sessions.is_new_pb`). Needs
     `docs/migrations/2026-09-25-lead-piece-and-pb.sql`. 32 unit tests pass; checked in the
     simulator via manual entry + library photos. Next: step 2 (v3 foundation + tap fixes), then v3
     screens (feed carousel, lead-piece numbers and PB glow are built with the v3 feed).
   - **Step 2 (v3 foundation + tap reliability), BUILT** on branch `t24-v3-foundation` (`4921566`),
     stacked on `t23-review-session`. Root cause of mis-taps: `.plain` tab items only hit on drawn
     pixels, plus a card-wide feed tap. New: v3 tokens/type scale, v3 glass (app-wide), button
     family + `asButton`, sliding segmented control, v3 bottom nav (58 pt, 6 pt from bottom),
     full-screen Log. Verified by targeted simulator taps; 34 tests pass.
   - **Step 3 — Feed screen, BUILT** on branch `t25-v3-feed` (`0734209`), stacked on
     `t24-v3-foundation`: v3 header + search, Following/Club with caption, v3 card, carousel,
     lead-piece numbers, reactions (12-emoji v3 picker, saved and removable — verified), share,
     comments pill, PB glow (verified by snapshot test), empty states. "Explore clubs" for viewers
     without a club waits for phase G (the onboarding club search can't be reused for it).
     Next screens in order: Rankings, Profile, Log/Review, Settings, Other profile, Find rowers,
     PB history, All PBs, Onboarding.
   - **Rankings (Volume) BUILT** (`7a97110`): v3 layout; decisions 17–18 keep My club / Following
     only, Week / Month / Year and All / Erg / Water. v3 lists 7 tests; the app keeps its 9.
   - **Profile BUILT**: v3 header + Settings gear, centred identity, counts, 4-up stats, top PBs,
     estimate cards (dash until the algorithm arrives — decision 2), v3 weekly chart (tap a bar for
     its total), 7×12 consistency grid (fixes the wrapping month labels), recent activity →
     workout (new `.post` route). "Your club" button waits for phase G. Other-rower mode keeps
     phase E behaviour with v3 styling; the full §08 layout (rank mini-cards) is still to do.
   - **Log + Review BUILT** (`f864f86`): v3 §04/§05; library start = personal-only session; Help
     sheet; inset corner moved by press-and-hold (v3 has no corner button).
   - **Settings BUILT**: v3 §07 grouped cards; real Dark/Light appearance (app-wide, remembered);
     compact Metres|km (leaderboards) and Split|Watts; Privacy row → sheet; Edit profile screen;
     Log out; Contact + Terms (App Store requirement); Delete account; version. Left out: app icon
     (14), CSV (15); "Who can comment" needs the user's go-ahead.
   - **Notifications BUILT** (branch `t26-notifications`, decision 19): Settings switches + Quiet
     hours sheet, permission prompt, device registration, alert tap opens the post over anything.
     Server: migration `2026-09-26-notifications.sql`, `send-push` Edge Function (deployed to
     staging), database webhook. **Alerts reach a phone only after the paid Apple Developer Program
     is joined** and the push key is added — steps in `docs/testing/notifications.md` Part 3.
   - **Other rower's profile BUILT** (branch `t27-other-profile`, decisions 20–22): v3 §08
     exactly, with club rankings from `Core/Services/ClubRankService`.
   - **Find rowers BUILT** (v3 §09): header, search, one card of rows with glass follow pills
     and "Follow back"; Followers / Following lists share the layout. Shared `ScreenHeader`
     (Settings, Rower profile, people lists) and a `FollowButton.Variant`.
   - **PB history + All personal bests BUILT** (v3 §10–11, decision 23): shared `PBTileView`,
     `EstimateCard`, `StandardTest` titles. Fixes the chart's stray fill panel and the page not
     scrolling over the chart.
   - **Onboarding BUILT** (v3 §01 + "About you", decision 24): optional club; needs
     `docs/migrations/2026-09-29-onboarding.sql` run on staging before a new rower can finish it.
   - **Clubs BUILT** (v3 §12 + phase G, decision 25, branch `t28-clubs`): Your crew hub, create/
     edit club, Manage club (requests, invites + code, members and roles, hand over, delete),
     Profile club entry, join rules in onboarding. Needs `2026-09-30-clubs.sql` then
     `2026-09-30-club-directory.sql` on staging (`docs/testing/clubs.md`).
   - **Club follow-ups BUILT** (decision 26): one-club Your crew with every member, Requested /
     declined / Request again, invitation alerts and declined invites, live updates. Needs
     `2026-10-04-club-updates.sql` on staging.
   - **Tapping the tab you're on** (decision 27): Feed, Rankings and Profile scroll to the top
     and refresh.
   - **Club tests BUILT** (phase I, decision 28, branch `t31-tab-reselect`): "+ Add test" for
     club admins, club tests in the grid, the review dropdown and the post banner, delete from
     the board. Needs `docs/migrations/2026-10-04-club-tests.sql` on staging
     (`docs/testing/club-tests.md`).
   - **Seconds tests + profile pictures BUILT** (decisions 28–29, branch `t32-seconds-tests-avatars`).
     Needs `docs/migrations/2026-10-05-seconds-tests-and-avatars.sql` on staging
     (`docs/testing/seconds-tests-and-avatars.md`).
   - All v3 screens are now built.
   - **Known for step 3:** profile consistency grid month labels wrap letter by letter ("M / ar").
     Note: the clickable prototype renders an 8 pt nav gap; `RP Screen.dc.html` and the README say
     4 pt — 4 pt is used.
4. **G — Clubs. BUILT and merged** (decisions 25–26). Create club, join policy (open / approval / invite), roles
   (owner / co-owner / admin / member), join requests, owner-only management, onboarding policy
   tags and "Join request pending". Needs schema (roles, policy, requests). Existing base:
   `Features/Onboarding/ClubSearchView`.
5. **H — Settings overhaul. DONE as far as decided:** the app-icon picker is out (decision 14)
   and so is CSV (decision 4); notifications, quiet hours, privacy and the account section are
   built. "Who can comment" is settled as a rule, not a setting (decision 33, branch
   `t34-post-visibility`; needs `2026-10-05-post-visibility.sql` on staging). Original scope: App-icon picker (alternate icons; artwork already added), notification
   toggles, privacy row (needs E), account section. **No CSV export** (decision 4). Quiet hours and
   "Who can comment" are placeholders: confirm before building.
6. **I — Custom tests. BUILT as club tests** (decision 28) — see above.
7. **J — Feed extras. BUILT** (decision 32, branch `t33-comments-share`): full-screen comments
   thread (feed comments pill, and "View all" on the workout) and the share-workout image card
   with preview. The 12-emoji picker was built with the v3 feed. No migration needed
   (`docs/testing/comments-and-share.md`).
8. **K — Prediction cards.** The algorithm arrived 2026-10-05 as the Pace Engine
   (`PaceEngine/`, Python source of truth). Phase 1 DONE: Swift port in `Packages/PaceEngine`,
   all 38 golden cases + 34 parsing checks pass. Phase 2 part 1 DONE (decisions 30–31): zone,
   effort and rep distance on posts; private date of birth and weight. Phase 2 part 2 DONE: the package
   is in the app target; `PredictionService` feeds the engine each zoned erg session's main
   segment(s) from the last 60 days; predictions show on the Profile 2k/5k cards, on the Test
   results distance tiles, and in the "How we got this" sheet (`docs/testing/pace-engine.md`).
   Population prior DONE (engine v1.4, 2026-10-05): cold-start baselines and the age curve from
   27 up fitted from the Concept2 rankings medians (SPEC.md §7.6,
   `PaceEngine/fit_population_prior.py`); the Population Estimate stays off by the user's choice.
   After launch: tune the tier constants on a real cohort (SPEC.md §7.2) — there is no real data
   until rowers start posting, so this waits for the live app (user, 2026-10-05).
9. **L — Polish and release.** Tab bar: fine for now (user, 2026-10-05). Light mode already
   exists (Settings → Appearance); what's left is a screen-by-screen check of it and of Increase
   Contrast, full screen-by-screen comparison against the
   prototype, then task 19 (TestFlight).

10. **Coaching and the v4 canvas** (decisions 34–41): canvas catch-up, then coaching Phases 1–3 in
    `docs/design/coaching-build-plan.md`. Catch-up BUILT (branch `t36-canvas-catch-up`, `docs/testing/canvas-catch-up.md`); next: coaching Phase 1.

## Waiting on the user

- ~~The prediction algorithm (phase K)~~ — arrived and built; tuning waits for post-launch data.
- ~~Concrete description of what is still wrong with the tab bar (phase L)~~ — not an issue for now (2026-10-05).
- ~~Go-ahead on the placeholder "Who can comment"~~ — decision 33.
- ~~Joining the paid Apple Developer Program~~ — done 2026-10-04; push alerts work.
