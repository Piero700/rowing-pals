# WhatsApp share picture and rower web page — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Coaches share the week or a workout to WhatsApp as a picture; rowers without an iPhone answer Available / Can't, Can you race? and check in at rowingpals.com/go.

**Architecture:** iPhone side: pure rules build the card's rows, a SwiftUI card is rendered with `ImageRenderer` in the dark palette, and a sheet shares the image plus the link through the iPhone share screen. Web side: a static React app in `web/` that talks to the same Supabase project through the same database functions the app already calls; the only server change is letting two Edge Functions answer browsers (CORS).

**Tech Stack:** SwiftUI, Swift Testing; React 18 + TypeScript + Vite, `@supabase/supabase-js` v2, `react-router-dom` v6, Vitest; Netlify; Supabase Edge Functions (Deno).

**Spec:** `docs/superpowers/specs/2026-11-19-whatsapp-share-and-rower-web-design.md` (decision 110). Read it first.

## Global Constraints

- UK English in all copy; metres not meters; split never "pace", rate never "cadence".
- iPhone: every colour, size and spacing from `DesignSystem/` tokens; `.monospacedDigit()` on every numeral; no gradients; no force-unwraps; one type per file; never hand-edit `project.pbxproj`; push screens through `RouteHost`; build screens from small `View` structs (ScreenStackDepthTests, 700 KB).
- Web: every colour/size from `web/src/tokens.css`; `font-variant-numeric: tabular-nums` on everything; grouped rows (one card per group, 12 px corners, 44 px rows); no gradients; dark first, light follows the system.
- The card is always drawn dark: `.environment(\.colorScheme, .dark)` on the rendered view.
- Card footer copy, exactly: "No iPhone? Say if you can make it at rowingpals.com/go".
- The link passed with the picture, exactly: `https://rowingpals.com/go`.
- No rowers' names, crews or seats on any card.
- Age copy, exactly: "Rowing Pals is for people 13 and over." Minimum age 13, adult 18.
- Can't reason helper, exactly: "Only coaches see this".
- Check-in window: from 30 minutes before `starts_at` until `ends_at`, not cancelled.
- Coach notice on the web, exactly: "Coach tools are in the iPhone app for now."
- Web Supabase URL/key only from `web/.env.staging` / `web/.env.production` (gitignored); `npm run dev` uses staging. Never hardcode.
- Test account values are generated, kept only as comments in the gitignored `web/.env.staging`, never written in chat.
- Dates are grouped by the rower's local calendar day, never UTC.

## Review Focus

1. **A practice near midnight or across the clocks changing** (Sun 26 Oct 2026, BST ends) lands on the rower's local day → Task 6 `groupByLocalDay` test.
2. **Check-in at the exact edges** (exactly 30 min before; exactly at the end; one minute after; cancelled) → Task 6 `canCheckIn` tests.
3. **A busy week** (12 sessions, 60-character titles) renders without clipping, the card growing taller → Task 2 test.
4. **A Sunday-start club**: This week / Next week ranges and the card's dates follow `week_starts_on` → Task 1 and Task 6 tests.
5. **Someone arriving at /go part-way through setting up** (no username, no date of birth, no club, waiting for approval, a coach) lands on the right screen → Task 8 `nextStep` tests.

---

### Task 1: Week card rows (pure rules)

**Files:**
- Create: `Rowing Pals/Core/Services/ShareCardRules.swift`
- Create: `Rowing Pals/Core/Models/ShareCardRow.swift`, `Rowing Pals/Core/Models/ShareAudience.swift`
- Test: `Rowing PalsTests/ShareCardRulesTests.swift`

**Interfaces:**
- Produces:
  - `struct ShareCardRow: Equatable, Identifiable { let id: String; let start: Date; let dayText: String; let timeText: String?; let title: String; let detail: String? }`
  - `enum ShareAudience: Equatable, Hashable { case club; case squad(UUID) }`
  - `ShareCardRules.weekRows(practices: [Practice], workouts: [CoachWorkout], water: [WaterSession], events: [ClubEvent], audience: ShareAudience, range: DateInterval, calendar: Calendar) -> [ShareCardRow]`, sorted by `start`.
  - `ShareCardRules.dateRangeText(_ range: DateInterval, calendar: Calendar) -> String`: "24–30 Nov"; across months "28 Nov – 4 Dec".
  - `ShareCardRules.workoutRows(_ workout: CoachWorkout) -> [ShareCardRow]`: one row per piece from `WorkoutRules.pieceTitle` / `pieceDetail` / `rateText`.
  - `static let footer = "No iPhone? Say if you can make it at rowingpals.com/go"`; `static let link: URL?` for `https://rowingpals.com/go` (callers `guard`, never `!`).

Rules the tests pin:
- Workout row: title "Erg · " + (`WorkoutRules.piecesSummary(pieces)` ?? `workout.title`); detail is `rateText(pieces)` and `restText(pieces)` joined with " · ", nil if both nil. Workouts with `audience == .rowers` are left out of week cards.
- Practice row: title `displayTitle`; detail `place`. Cancelled practices are left out.
- Water row: title "Water"; detail "meet \(meetAt)" when set.
- Event row: title `name`; detail `place`; `timeText` nil; a multi-day event appears once, on its first day in range.
- Squad filter: a practice or event is kept when its `squadIds` is empty (whole club) or contains the squad; a workout when `audience == .club` or its `squadIds` contains the squad; a water session follows its linked practice or event, and one with neither is kept.

- [ ] **Step 1: Write the failing tests** in `ShareCardRulesTests` (Swift Testing):
  - `rowsAreInTimeOrderAndSkipCancelled`: Tue 06:30 workout of 3 × 2000m, Thu 06:30 water session meeting "06:15", a cancelled Wed practice → titles `["Erg · 3 × 2k", "Water"]` (the first uses whatever `piecesSummary` returns), second detail `"meet 06:15"`.
  - `squadCardKeepsSquadAndWholeClubSessions`: practices for squad A, squad B and no squads; `.squad(A)` → 2 rows.
  - `individualWorkoutsAreLeftOut`: `audience: .rowers` → 0 rows.
  - `multiDayEventAppearsOnce`: event Sat–Sun → 1 row, on Sat.
  - `dateRangeFollowsWeekStart`: Monday-start week containing 24 Nov 2026 → "24–30 Nov"; Sunday-start → "23–29 Nov"; range 28 Nov–4 Dec → "28 Nov – 4 Dec".
  - `busyWeekKeepsEveryRow`: 12 sessions → 12 rows.
- [ ] **Step 2: Run them to see them fail**: XcodeBuildMCP `test_sim` (after `session_show_defaults`) with `-only-testing:Rowing PalsTests/ShareCardRulesTests`. Expected: build fails, `ShareCardRules` not defined.
- [ ] **Step 3: Implement** the files above.
- [ ] **Step 4: Run the tests.** Expected: all pass.
- [ ] **Step 5: Commit**: `Share card rows for the week and a workout (decision 110)`.

### Task 2: The card view

**Files:**
- Create: `Rowing Pals/Features/Calendar/ShareWeekCardView.swift`, `ShareCardRowView.swift`, `ShareCardFooter.swift`
- Modify: `Rowing Pals/DesignSystem/Tokens.swift`: add `enum ShareWeek` (width 360 pt = 1080 px at scale 3, row spacing, row inner padding) beside `Size.shareCardWidth`.
- Test: `Rowing PalsTests/ShareWeekCardTests.swift`

**Interfaces:**
- Consumes: `ShareCardRow`, `ShareCardRules.footer` (Task 1).
- Produces: `struct ShareWeekCardView: View { let heading: String; let subheading: String; let rows: [ShareCardRow] }`, used for both cards: week (heading "This week" / "Next week", subheading "Novice men · 23–29 Nov") and workout (heading the workout title, subheading "Wed 25 Nov · 06:30"). Empty `rows` shows "Nothing planned yet".

Look: `Tokens.Base.ground` behind, rows on `Tokens.Surface.card` with `Tokens.Radius.card` corners; day and time in `Tokens.Accent.brand` on the left, title `Ink.primary`, detail `Ink.secondary`; footer line in brand blue, then the wordmark as `ShareCardView` draws it. Fixed width, height from content.

- [ ] **Step 1: Write the failing tests** (`@MainActor`, render as `ShareCardTests` does, scale 3):
  - `rendersAtSharedWidth`: 3 rows → `image.size.width * image.scale == 1080`.
  - `busyWeekGrowsTaller`: 12 rows with 60-character titles → taller than the 3-row image, width still 1080.
  - `emptyWeekStillRenders`: 0 rows → an image.
  - `alwaysDark`: render inside `.environment(\.colorScheme, .light)`; the top-left pixel equals #101114.
- [ ] **Step 2: Run** with `-only-testing:Rowing PalsTests/ShareWeekCardTests`. Expected: build fails.
- [ ] **Step 3: Implement** the views and tokens; `.environment(\.colorScheme, .dark)` inside `ShareWeekCardView`.
- [ ] **Step 4: Run the tests.** Expected: pass.
- [ ] **Step 5: Commit**: `Share card view for the week and a workout`.

### Task 3: Share week / Share workout sheet, wired in

**Files:**
- Create: `Rowing Pals/Features/Calendar/ShareWeekSheet.swift`, `ShareWeekViewModel.swift`, `ShareWeekOptions.swift` (the Which week / Who for card, from `GroupedForm`).
- Create: `Rowing Pals/DesignSystem/ActivityShareSheet.swift`: a `UIViewControllerRepresentable` around `UIActivityViewController(activityItems: [UIImage, URL])`. `ShareLink` takes one item, and the picture and link must go together.
- Modify: `Rowing Pals/Features/Calendar/CoachCalendarView.swift:94-98`: add `GlassIconButton(icon: .share, accessibilityLabel: "Share week")` in the `CoachTabHeader`, presenting the sheet.
- Modify: `Rowing Pals/Features/Coaching/WorkoutResultsView.swift:89-95`: add `GlassIconButton(icon: .share, accessibilityLabel: "Share workout")`.
- Test: `Rowing PalsTests/ShareWeekViewModelTests.swift`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: `@Observable final class ShareWeekViewModel` with `enum Mode { case week; case workout(UUID) }`, `enum Which { case thisWeek, nextWeek }`, `var which`, `var audience: ShareAudience`, `func load() async`, `var heading: String`, `var subheading: String`, `var rows: [ShareCardRow]`, `@MainActor func render() -> UIImage?`. A second init takes already-loaded arrays plus `today` and `weekStart`, for tests.

Data: week mode loads the chosen week with the same service calls `CoachCalendarViewModel.load()` uses (practices, workouts, water sessions, events, squads), limited to the week from `CalendarService.weekStart()`. Workout mode loads the workout as `WorkoutResultsViewModel` does. The sheet shows the preview like `ShareWorkoutSheet`, then **Share** opens `ActivityShareSheet` with the image and `ShareCardRules.link`. Who for lists Whole club, then each squad by name. Subheading: squad name (or club name), " · ", `dateRangeText`.

- [ ] **Step 1: Write the failing tests** with the test init:
  - `nextWeekHeadingAndDates`: `.nextWeek`, Monday start, today Thu 19 Nov 2026 → heading "Next week", subheading ends "23–29 Nov".
  - `squadNameInSubheading`: `.squad(A)` named "Novice men" → subheading starts "Novice men · ".
  - `workoutModeUsesWorkoutTitle`: heading is the workout's title; subheading "Wed 25 Nov · 06:30".
- [ ] **Step 2: Run** with `-only-testing:Rowing PalsTests/ShareWeekViewModelTests`. Expected: build fails.
- [ ] **Step 3: Implement** the view model, sheet, options card and share wrapper; wire both buttons.
- [ ] **Step 4: Run the whole suite** (`test_sim`, no filter). Expected: all pass, ScreenStackDepthTests included.
- [ ] **Step 5: Build, run and screenshot** with the `rp-verify` skill: Calendar → Share week → preview for This week · Whole club and Next week · one squad; a workout → Share workout. Compare with the spec; say what differs.
- [ ] **Step 6: Commit**: `Share week and Share workout to WhatsApp as a picture (decision 110)`.

### Task 4: Let two Edge Functions answer browsers

**Files:**
- Create: `supabase/functions/_shared/cors.ts`: `corsHeaders(origin: string | null)` allowing `https://rowingpals.com`, the staging web address (from an env var `WEB_ORIGINS`, comma-separated) and `http://localhost:5173`; headers `authorization, x-client-info, apikey, content-type`; methods `POST, OPTIONS`.
- Modify: `supabase/functions/username-auth/index.ts`, `supabase/functions/delete-account/index.ts`: answer `OPTIONS` with 200 and the headers; add the headers to every response, errors included. Nothing else changes.

- [ ] **Step 1:** Deploy both to **staging** only: `supabase functions deploy username-auth --project-ref <staging ref>` and the same for `delete-account` (the ref is in `Staging.xcconfig`'s Supabase URL).
- [ ] **Step 2: Verify**: `curl -i -X OPTIONS -H "Origin: http://localhost:5173" -H "Access-Control-Request-Method: POST" https://<staging ref>.supabase.co/functions/v1/username-auth` → `200` with `access-control-allow-origin: http://localhost:5173`; the same for `delete-account`. Then sign in by username in the iPhone app on staging: still works.
- [ ] **Step 3: Commit**: `Edge Functions answer the web page (CORS)`. The production deploy happens at launch (Task 11).

### Task 5: The web app's base

**Files:**
- Create: `web/` with `npm create vite@latest web -- --template react-ts`; add `@supabase/supabase-js`, `react-router-dom`; dev `vitest`, `@testing-library/react`, `jsdom`.
- Create: `web/src/tokens.css` (the CLAUDE.md palette dark and light, the type scale, `--radius-card: 12px`, `--row-height: 44px`); `web/src/lib/supabase.ts` (`createClient` from `import.meta.env.VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`, `persistSession: true`; a clear error if either is missing); `web/src/components/GroupedCard.tsx`, `GroupedRow.tsx`.
- Create: `web/.env.example` (variable names only), `web/netlify.toml` (`publish = "dist"`, redirect `/go/*` → `/go/index.html` status 200); `vite.config.ts` with `base: "/go/"`.
- Modify: root `.gitignore`: `web/.env.*` except `web/.env.example`, `web/node_modules`, `web/dist`.

- [ ] **Step 1: Write a failing smoke test** `web/src/App.test.tsx`: renders `<App />` and finds "Sign in".
- [ ] **Step 2: Run** `cd web && npx vitest run`. Expected: fail, no `App`.
- [ ] **Step 3: Implement** `App.tsx` with the router and the Sign in route; load the tokens in `main.tsx`.
- [ ] **Step 4: Run** `npx vitest run` → pass; `npm run build` → `dist/` with no errors.
- [ ] **Step 5: Commit**: `Web page base: React, Vite, tokens, Supabase client`.

### Task 6: Web rules (ported from Swift)

**Files:**
- Create: `web/src/rules/username.ts` (`normalised`, `problem` with the limits and messages of `UsernameRules.swift`, `isEmail`); `web/src/rules/age.ts` (`MINIMUM_AGE = 13`, `ADULT_AGE = 18`, `TOO_YOUNG_MESSAGE`, `ageOn(birth: string, today: Date): number`, `isOldEnough(birth: string, today: Date): boolean`); `web/src/rules/calendar.ts` (`weekStart(date: Date, startsOn: "monday" | "sunday"): Date`, `weekRange(which: "this" | "next", today: Date, startsOn): { from: Date; to: Date }`, `canCheckIn(p: { startsAt: Date; endsAt: Date; cancelled: boolean }, now: Date): boolean`, `groupByLocalDay<T>(items: T[], start: (t: T) => Date): { day: string; items: T[] }[]`, `timeText(d: Date)` → "06:30", `dayHeading(d: Date)` → "Tue 25 Nov").
- Test: `web/src/rules/username.test.ts`, `age.test.ts`, `calendar.test.ts`

- [ ] **Step 1: Write failing tests** using the values in `UsernameTests.swift`, `AgeRulesTests.swift` and `CalendarRulesTests.swift`, plus:
  - `canCheckIn`: true at exactly 30 min before and exactly at the end; false at 31 min before, 1 min after the end, and when cancelled.
  - `groupByLocalDay` under `TZ=Europe/London`: 23:30 Sat 25 Oct 2026 and 00:30 Sun 26 Oct land on two different days.
  - `weekRange("next", Thu 19 Nov 2026, "sunday")` → Sun 22 Nov 00:00 to Sun 29 Nov 00:00 local.
- [ ] **Step 2: Run** `TZ=Europe/London npx vitest run src/rules`. Expected: fail.
- [ ] **Step 3: Implement** the three files.
- [ ] **Step 4: Run.** Expected: pass. Set `"test": "TZ=Europe/London vitest run"` in `package.json`.
- [ ] **Step 5: Commit**: `Web rules: usernames, age, calendar`.

### Task 7: Sign in, create account, codes, reset, Google

**Files:**
- Create: `web/src/auth/SignInScreen.tsx`, `CreateAccountScreen.tsx`, `VerifyCodeScreen.tsx`, `ResetScreen.tsx`, `authService.ts`, `profileFromMetadata.ts`.
- Test: `web/src/auth/profileFromMetadata.test.ts`, `authService.test.ts`

**Interfaces:**
- Produces, in `authService.ts`:
  - `signIn(identifier, password)`: an email → `auth.signInWithPassword`; a username → `functions.invoke("username-auth", { body: { action: "sign-in", username: normalised(identifier), password } })`, then `auth.setSession` with the returned `access_token` / `refresh_token`.
  - `signUp({ name, email, password, birthDate })`: metadata keys exactly `display_name`, `birth_date` ("YYYY-MM-DD"), `terms_accepted_at` (ISO 8601). With no session back, go to the code screen.
  - `verifySignupCode(email, code)`: `auth.verifyOtp({ type: "signup" })`.
  - `sendReset(identifier)`: email → `resetPasswordForEmail`; username → action `send-reset`.
  - `resetWithCode(identifier, code, newPassword)`: email → `verifyOtp({ type: "recovery" })` then `updateUser({ password })`; username → action `reset` with `code` and `newPassword`.
  - `signInWithGoogle()`: `signInWithOAuth({ provider: "google", options: { redirectTo: location.origin + "/go/" } })`.
  - `ensureProfileExists()`: as `SignInViewModel.ensureProfileExists`: insert `profiles { id, display_name, terms_accepted_at }` if missing; then save `birth_date` to `athlete_private` if the metadata has one.
- `profileFromMetadata(meta: Record<string, unknown>, email: string | null): { displayName: string; termsAcceptedAt: string }`: name from `display_name`, then `full_name`, `name`, the email's local part, "Rower"; cut to 40 characters.

Create account refuses an under-13 date with the age copy and makes no account. Terms and Privacy link to `https://rowingpals.com/terms` and `/privacy`.

- [ ] **Step 1: Write failing tests**: `profileFromMetadata` (display_name wins; falls back to the email's local part; a 45-character name is cut to 40); `signIn` with a mocked client calls the username function for "joe.bloggs" and `signInWithPassword` for "joe@example.com".
- [ ] **Step 2: Run** `npm test`. Expected: fail.
- [ ] **Step 3: Implement** the service and four screens (grouped rows; errors under the card in the error colour).
- [ ] **Step 4: Run** `npm test` → pass.
- [ ] **Step 5: In the browser pane** (`npm run dev`, `http://localhost:5173/go/`, staging): create a generated test account (values kept as comments in `web/.env.staging`), confirm its `profiles` row exists, sign out, sign in by username, reset the password by email.
- [ ] **Step 6: Commit**: `Web sign in, create account, codes and reset`.

### Task 8: Setting up: username, date of birth, club

**Files:**
- Create: `web/src/setup/nextStep.ts`, `UsernameScreen.tsx`, `BirthDateScreen.tsx`, `JoinClubScreen.tsx`, `WaitingScreen.tsx`, `setupService.ts`.
- Test: `web/src/setup/nextStep.test.ts`

**Interfaces:**
- Produces: `nextStep(s: { signedIn: boolean; username: string | null; birthDate: string | null; clubStatus: "none" | "requested" | "member"; isCoach: boolean }): "signIn" | "username" | "birthDate" | "club" | "waiting" | "week"`. A coach goes to `"week"`, which then shows the coach notice as a banner.
- `setupService`: `usernameAvailable` / `setUsername` (rpcs `username_available`, `set_username`); `saveBirthDate`; `clubForCode`, `joinWithCode`, `joinClub`, `cancelRequest` (rpcs as in `ClubService.swift`); `searchClubs(text)` (the query in `ClubSearchViewModel.swift:82`); `loadSetupState()`.

Under 13 on the birth date screen offers **Change date** and **Delete my account**, with the app's wording "If the date is right, your account and everything in it will be deleted. This can't be undone."; deleting calls `functions.invoke("delete-account")`, then signs out.

- [ ] **Step 1: Write failing tests** for `nextStep`: signed out → signIn; no username → username; no date → birthDate; no club → club; requested → waiting; member → week; coach member → week.
- [ ] **Step 2: Run** `npm test`. Expected: fail.
- [ ] **Step 3: Implement** the function, the service and the screens; every signed-in visit goes through `nextStep`.
- [ ] **Step 4: Run** → pass. In the browser pane, join the staging test club by its code; check in the simulator (coach account) that the member appears.
- [ ] **Step 5: Commit**: `Web setup: username, date of birth, joining a club`.

### Task 9: Your week

**Files:**
- Create: `web/src/week/WeekScreen.tsx`, `DayCard.tsx`, `PracticeRow.tsx`, `EventRow.tsx`, `ReasonSheet.tsx`, `weekService.ts`, `buildWeek.ts`.
- Test: `web/src/week/buildWeek.test.ts`

**Interfaces:**
- Consumes: `weekRange`, `groupByLocalDay`, `canCheckIn`, `timeText`, `dayHeading` (Task 6).
- Produces:
  - `weekService.load(which: "this" | "next")` → `{ practices, events, myAnswers, myEventAnswers, startsOn }` from `clubs.week_starts_on`, rpc `my_practices(p_from, p_to)`, rpc `my_events(p_from)` (cut to the range), and the rower's own rows of `attendance_responses` and `event_responses`.
  - `respond(practiceId, answer: "going" | "cant" | null, reason?)` → rpc `respond_practice`; `checkIn(practiceId)` → rpc `check_in_practice`; `respondEvent(eventId, answer: "yes" | "no" | null, reason?)` → rpc `respond_event`.
  - `buildWeek(data, now: Date): { day: string; heading: string; items: WeekItem[] }[]`, where `WeekItem` holds the practice or event, the rower's answer, `checkInOpen: boolean` and `checkedInText: string | null` ("Checked in 06:24").

Screen: This week · Next week; one card per day. Practice row: time, title, place, then **Available / Can't**; Can't opens the reason sheet ("Only coaches see this", optional); **Check in** only while `checkInOpen`. Race row: **Can you race?** Yes / No, optional reason, shown only when the event's `asks_availability` is true (otherwise just its name, dates and place). A cancelled practice shows "Cancelled" and no buttons. Database errors (e.g. "Check-in opens 30 minutes before the start.") show under the row.

- [ ] **Step 1: Write failing tests** for `buildWeek`: items on the right days in time order; `checkInOpen` true 10 min before the start and false after the end; "Checked in 06:24" from `checked_in_at`; a cancelled practice kept with no actions.
- [ ] **Step 2: Run** `npm test`. Expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** → pass. In the browser pane on staging: answer Can't with a reason on a test practice; check in to one starting within 30 minutes; in the simulator (coach), Who's available and the register show both.
- [ ] **Step 5: Commit**: `Web week: Available / Can't, Can you race?, check in`.

### Task 10: Account

**Files:**
- Create: `web/src/account/AccountScreen.tsx`
- Test: `web/src/account/AccountScreen.test.tsx`

Rows: username, club, **Leave club** (rpc `leave_club`, confirmed on the page), **Sign out**, **Delete account** (red row; confirmed on the page with the app's wording; `functions.invoke("delete-account")`; then signs out and shows "Your account has been deleted.").

- [ ] **Step 1: Write a failing test**: the first tap on Delete account shows the confirmation and does not call the function (mocked client).
- [ ] **Step 2: Run** → fail. **Step 3: Implement.** **Step 4: Run** → pass; in the browser pane delete the staging test account and confirm it's gone.
- [ ] **Step 5: Commit**: `Web account: leave club, sign out, delete account`.

### Task 11: Docs, checklist and putting it online

**Files:**
- Modify: `docs/design/v2-decisions.md`: decision 110 (the spec's choices, the files, the checklist).
- Modify: `CLAUDE.md`: Current focus; Stack gains "Web page for rowers: React, Vite, TypeScript in `web/`".
- Modify: the website's `index.html` Coach section and FAQ ("No iPhone? Rowers can answer at rowingpals.com/go") and the Privacy Policy (the web page; browser storage used only to stay signed in).
- Create: `docs/testing/whatsapp-share-and-web.md`: phone checklist — share both cards into a real WhatsApp group (does the link arrive as the caption; is the picture readable), an Android phone through every web screen, the coach sees answers and check-ins.
- Create: `docs/production/web-launch.md`: click-by-click — make the staging Netlify site (base `web`, build `npm run build -- --mode staging`, env vars), add its address and `http://localhost:5173/go/` to Supabase → Authentication → URL Configuration on staging, the Google redirect; at App Store launch, the production env, deploying both functions to production, adding `https://rowingpals.com/go/` to production's redirects, publishing `/go` with the website.

- [ ] **Step 1:** Write the docs.
- [ ] **Step 2: Full checks**: iPhone `test_sim` → all pass; `cd web && npm test && npm run build` → pass.
- [ ] **Step 3: Commit**: `Decision 110: docs, checklist and web launch steps`.
