# Rowing Pals — build tasks 01–19

Written as instructions to you, the agent. Work one task at a time.

---

## 01 — Design tokens

**Read first:** `docs/design-brief.md` → "Visual direction", "Palette", "Typography".

Create `DesignSystem/Tokens.swift` defining every colour as a static property on an enum,
resolving correctly in both light and dark via asset catalog colour sets or dynamic `UIColor`.
Create `DesignSystem/Typography.swift` with the type scale; every numeric style applies
`.monospacedDigit()`. Create `TokenPreview.swift` showing every colour swatch with its name and
hex, and every type style.

**Verify:** Build, launch, screenshot. Exactly three accent swatches must appear —
`#3AD7E5`, `#F5C542`, `#FF6B5A`. Then switch the simulator to light mode and screenshot again.
Both must be legible.

**Fails as:** colours hardcoded inline in views instead of read from tokens. This is expensive
to unpick later — do it properly now.

---

## 02 — Glass surfaces

Use SwiftUI's **native** Liquid Glass APIs. Do not hand-build blur or gradient stacks.

Create `DesignSystem/Glass.swift` using `.glassEffect(_:in:)` with `Glass.regular`, `.clear`,
`.tint()` and `.interactive()` as appropriate, and `GlassEffectContainer` for grouping adjacent
glass elements so they blend. Create a `GlassPreview` screen showing a glass card, a
`.buttonStyle(.glass)` button and a `.glassProminent` one, all layered over a photo.

Check Apple's current documentation for exact signatures before writing — these APIs are new
and change between releases.

**Verify:** Screenshot must show refraction and a specular rim on the glass edges over the
photo. A flat grey rectangle at low opacity means you built a fake — try again.

**Fails as:** `'glassEffect' is unavailable` → the deployment target is below iOS 26. Tell the
user to raise it; do not work around it.

---

## 03 — Build configurations and secrets

Do this before any Supabase key exists anywhere in the project.

Add Debug, Staging and Release build configurations. Create `Config/Debug.xcconfig`,
`Config/Staging.xcconfig` and `Config/Release.xcconfig`, each defining `SUPABASE_URL` and
`SUPABASE_ANON_KEY`, surfaced into Info.plist and read at runtime through
`Core/AppConfig.swift`. Give Debug the bundle suffix `.dev` and display name "RP Dev";
Staging `.beta` and "RP Beta". Confirm `*.xcconfig` is gitignored. Commit
`Config/Example.xcconfig` with placeholder values only.

**Verify:** Build all three configurations and report each result. Then run
`git status --porcelain | grep xcconfig` — it must return nothing except `Example.xcconfig`.

---

## 04 — App shell and floating tab bar

The bar must float, detached, and minimise on scroll. **This is a system behaviour — do not
hand-build it.** Use `.tabBarMinimizeBehavior(.onScrollDown)` on the `TabView`, and
`.tabViewBottomAccessory { }` for content that sits above the bar.

Create `App/RootView.swift` with five tabs — Feed, Metres, Post, Tests, Profile — each a
placeholder showing its name. The Post tab presents a sheet rather than switching tabs. Put a
long scrolling list in the Feed placeholder so the minimise behaviour is testable.

**Verify:** Two screenshots that visibly differ — full-width bar, then a shrunk pill after
scrolling. Content must be visible through the bar in both.

**Fails as:** bar doesn't minimise → the scroll view isn't a direct descendant of the tab
content. Restructure rather than faking it.

---

## 05 — Supabase client, models, email auth

Add `github.com/supabase/supabase-swift` via Swift Package Manager. Create
`Core/Services/SupabaseService.swift` exposing one shared `SupabaseClient` built from
`AppConfig`.

Create Codable structs in `Core/Models/` mirroring `docs/schema.sql` **exactly** — `Profile`,
`Club`, `Session`, `Segment`, `TestResult`, `DailyTotal` — with coding keys matching the
snake_case columns, durations as `Int` milliseconds, distances as `Int` metres.

Build `Features/Onboarding/SignInView.swift` with email sign-up and sign-in. On first sign-in,
insert a `profiles` row with the display name. Use only design tokens.

**Verify:** Sign up in the simulator, then query `select * from profiles;` in Supabase — the row
must exist with the right `display_name`.

**Fails as:** `No such module 'Supabase'` → package added to the project but not the app target.
Row missing with no error → RLS rejected the insert; check the `profiles` policy.

---

## 06 — Club directory and onboarding

**Read first:** `docs/design-brief.md` → "Screen 1 — Onboarding".

Tell the user to seed a few clubs by hand in the Supabase Table Editor first, or the search
screen has nothing to find.

Build `Features/Onboarding/ClubSearchView.swift`: a searchable list querying `clubs` with
case-insensitive matching on name, showing name, location and member count. Then a profile
setup step collecting display name, gender, and a Novice/Senior segmented control with the
explainer copy from the brief. Write selections to the user's `profiles` row.

**Verify:** Search finds a seeded club. After setup, `profiles.club_id` and `profiles.category`
are correct in Supabase.

---

## 07 — Single-camera capture and upload

**Physical iPhone required.** The simulator has no camera.

Single camera only — dual capture is task 08. Getting one photo to the database proves the
pipeline; doing both at once means a failure could be in either half.

Build `Features/Capture/CaptureView.swift` with an `AVCaptureSession` rear-camera preview and a
shutter button using `AVCapturePhotoOutput`. On capture: downscale to 1600px on the long edge,
encode JPEG at 0.7, upload to the `monitors` Storage bucket at `userID/UUID.jpg`, then insert a
`sessions` row with type `erg`, `session_date` as the user's **local** calendar day, and
placeholder distance and time. Add `NSCameraUsageDescription` to Info.plist as a real sentence.
Create `Core/Services/StorageService.swift`.

**Verify:** Photo taken on the phone produces both a file in the bucket and a row in `sessions`.
Confirm `session_date` is today's local date, not yesterday's UTC date.

**Fails as:** crash the instant the camera opens → `NSCameraUsageDescription` missing. Silent
upload failure → bucket policy doesn't allow authenticated inserts.

---

## 08 — Dual-camera capture

**Physical iPhone required. iPhone 11 or later.**

Upgrade `CaptureView` to simultaneous front and rear capture using `AVCaptureMultiCamSession`.
Guard on `AVCaptureMultiCamSession.isMultiCamSupported` and fall back to sequential capture
(rear then front) where unsupported. Rear uploads to `monitors`, front to `selfies`; both paths
go on the same `sessions` row. Rear preview full-bleed with the front preview as a small inset,
per `docs/design-brief.md` → "Screen 3". Add the capture-window countdown using the coral token.

**Verify:** One shutter press produces two files in two buckets, referenced from one row.

**Fails as:** session won't start → multi-cam is strict about format compatibility between
inputs. Log the `AVCaptureSession.runtimeErrorNotification` payload rather than guessing.

---

## 09 — Vision OCR

Create `Core/Services/OCRService.swift` using `VNRecognizeTextRequest` with
`recognitionLevel = .accurate` and **`usesLanguageCorrection = false`**. Language correction
rewrites digits into words and will destroy every reading — this is not optional.

Return every `VNRecognizedTextObservation` with its normalised `boundingBox`, not just the
strings. Then write a `MonitorParser` mapping observations to fields using their **relative
geometry** on the PM5 layout — elapsed time, distance in metres, /500m split, stroke rate.
Position identifies the field, not the text. Return a confidence per field.

Add a test target running the parser over every image in `docs/ocr-samples/`, printing extracted
values per file.

**Verify:** Run the tests over the sample set and report how many images produced all four
fields correctly. Below roughly 70%, iterate on the parser before anything is built on top.

**Fails as:** numbers returned as words, or `8:33.2` read as `B:33.2` → language correction is
still on.

---

## 10 — Review sheet and multi-segment sessions

**Read first:** `docs/design-brief.md` → "Screen 4 — Session review sheet".

Build `Features/Capture/ReviewSheet.swift`: session total on top, each captured photo as an
editable segment row with distance, time, split and rate, plus a Warmup/Main/Cooldown/Extra tag
picker. Low-confidence fields get a cyan underline and are pre-focused — **never red**, this is
expected rather than an error. Add "+ Add another photo" to append segments. Recompute the
session total from segments whenever a field changes. On post, write one `sessions` row and N
`segments` rows, setting `was_edited` on any segment the user touched.

**Verify:** Post a three-segment session. `sessions.total_distance_m` must equal the sum of its
segments. Edit one field before posting; only that segment has `was_edited = true`.

---

## 11 — Test detection prompt

In the review sheet, when the segment tagged Main matches a standard distance within tolerance
— 500m, 1k, 2k, 5k, 6k, 10k, or a 4min/30min/60min time piece — show a distinct highlighted
block: "This looks like a 2k test. Add it to the 2k leaderboard?" with Yes/No. Only on Yes,
insert a `test_results` row.

**Critical:** write `gender_at_time` and `category_at_time` as **snapshots** of the user's
current profile values. Never a foreign key or live lookup — `docs/schema.sql` explains why.
Nothing enters the rankings without this tap.

**Verify:** Post a 2000m main piece and tap Yes. Then change the profile to Senior and re-query
`test_results` — `category_at_time` on the existing row must be unchanged.

---

## 12 — Feed

**Read first:** `docs/design-brief.md` → "Screen 2 — Feed".

Build `Features/Feed/FeedView.swift` and `FeedViewModel.swift` (`@Observable`). Query `sessions`
joined to `profiles`, newest first, paginated 20 at a time with infinite scroll. Card anatomy
exactly as the brief: header row, monitor photo full-bleed with the selfie as a tappable inset
that swaps, a glass data strip with total distance in large monospaced digits then time / split
/ rate, segment chips, verification badge. Add the Following / My Club / Global segmented
control. Cache images so scrolling doesn't refetch.

**Verify:** A post from a second account appears. Tapping the inset swaps the images. Scrolling
to the bottom loads page two.

**Fails as:** images flicker on scroll → no caching. Feed blanks after a few pages → pagination
cursor bug; print the query being sent.

---

## 13 — Metres leaderboard

**Read first:** `docs/design-brief.md` → "Screen 5".

Build `Features/Leaderboards/MetresLeaderboardView.swift` with Week/Month/Year segments, a
Male/Female filter, an All/Erg/Water source toggle, and Following/My Club/Global scope.
Aggregate from `daily_totals` — never scan `sessions`. Ranks 1–3 use the gold token and nothing
else does. Each row shows a thin two-tone bar of its erg/water split. Pin the current user's own
row above the tab bar, always visible. All numerals monospaced.

**Verify:** Insert known `daily_totals` rows by hand and confirm ranking and totals match
exactly. Switching Week → Month changes the numbers correctly.

---

## 14 — Test leaderboards

**Read first:** `docs/design-brief.md` → "Screen 6".

Two levels. First, a distance picker: a grid of glass tiles for 500m, 1k, 2k, 5k, 6k, 10k,
4min, 30min, 60min, each showing the user's own PB underneath or a dash. Second, an open
distance with stacked segmented controls — Male/Female on top, All/Novice/Senior below —
filtering on `category_at_time` and `gender_at_time` from the row, never the live profile.

Show only each rower's best result per distance, one row per person. Time in large monospaced
digits with the split beneath. Gold for ranks 1–3 and for any PB set in the last 7 days.

**Verify:** Insert two results for one user at different times — only the faster appears.
Switching to Novice filters on the snapshot column.

---

## 15 — Profile: PB board, streak, three charts

**Read first:** `docs/design-brief.md` → "Screen 7 — Profile". Build in the brief's order.

This is the largest task. If your plan looks unwieldy, propose splitting it: PB board and
streak first, charts second.

- **(a)** Header.
- **(b)** Streak block: call the `current_streak` SQL function from `docs/schema.sql`. Show the
  day count and the week's remaining rest days as filled/hollow pips. A spent rest day is
  neutral information — no red, no warning icon, no "don't lose your streak" copy.
- **(c)** Season strip.
- **(d)** PB board of glass tiles. Tapping a tile expands it into that distance's progression
  chart.
- **(e)** Weekly volume bars, 12 weeks, with the user's target as a dashed line.
- **(f)** Consistency calendar, 7 rows by 26 weeks, four shades of the cyan ramp by daily
  volume, horizontally scrollable.
- **(g)** Photo grid.

All charts read from `daily_totals` and `test_results` only. Use Swift Charts.

**Critical:** on the PB progression chart the y-axis is **time**, so faster is a smaller number.
**Invert the y-scale** so improvement reads as the line going up. Plotted naively an improving
season looks like a decline.

**Verify:** Insert five 2k results getting progressively faster — the line must rise left to
right. Log a session today, skip tomorrow, log the day after — the streak survives and one pip
is spent.

---

## 16 — Reactions, comments, following

**Read first:** `docs/design-brief.md` → "Screen 8 — Post detail".

Build `Features/Feed/PostDetailView.swift` with the full segment breakdown, a tap-reaction row
(fire, grimace, clap, eyes) writing to `reactions`, and a comment thread on `comments` with a
glass composer pinned above the tab bar. Use Supabase Realtime so new reactions and comments
arrive without a refresh. Add follow/unfollow on `profiles` and make the feed's Following scope
use it. If the post was a test, show the gold result banner with the rank.

**Verify:** Two devices, one post — react on A and it appears on B without a manual refresh.

---

## 17 — Moderation: all four Guideline 1.2 mechanisms

App Store Guideline 1.2 requires all four. Missing any one is the most common rejection for
apps like this. Build all four in this task.

1. **Filtering** — every uploaded photo through an image moderation check, every caption and
   comment through a text filter, *before* they become visible.
2. **Reporting** — a report control on every post and comment, writing to `reports`, with an
   in-app confirmation.
3. **Blocking** — block from a profile or a post. Their content disappears from my feed and
   mine from theirs, enforced in the query.
4. **Contact** — a support email link in Settings.

Also add a terms of service screen with a zero-tolerance clause, agreed at signup.

**Verify:** Block a test account — its posts vanish from your feed *and* yours from its feed.
Report a post and confirm the `reports` row.

---

## 18 — Account deletion and settings

Build `Features/Settings/SettingsView.swift`: edit profile, novice/senior toggle, weekly target,
support email, terms and privacy policy links, sign out, and Delete Account.

Deletion must complete **entirely in-app** — a confirmation step, then a Supabase Edge Function
removing the auth user and cascading all their rows and Storage objects. "Email us to delete" is
an App Store rejection.

**Verify:** Delete a throwaway account and confirm it's gone from `auth.users`, `profiles`,
`sessions` and Storage. Then confirm the same email can sign up again.

---

## 19 — TestFlight

Tell the user to buy the Apple Developer Program membership now, not earlier. Then:

1. App Store Connect → create the app record with the production bundle ID.
2. Create the production Supabase project; run `docs/schema.sql` against it unchanged. Fill in
   `Config/Release.xcconfig` with the production URL and key.
3. Complete App Privacy answers and the age rating questionnaire. Add privacy policy and
   support URLs — both must resolve.
4. Archive the Release configuration and upload to App Store Connect.
5. Add internal testers — no review, builds arrive in minutes.
6. Once stable, create an external group and submit for Beta App Review. Up to 10,000 testers
   by public link.

**Verify:** A teammate installs from TestFlight on their own phone, signs up, posts a session,
and it appears on yours.

**Fails as:** upload rejected for a missing privacy manifest → add `PrivacyInfo.xcprivacy`
declaring data collection and required-reason API use.
