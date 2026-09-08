# Rowing Pals — Build Plan

Sequencing, environments, and App Store requirements. Companion to `design-brief.md`,
which owns everything visual.

---

## Stack

- **SwiftUI**, native iOS. Liquid Glass design system.
- **Supabase** — Postgres, Auth, Storage, Realtime.
- **Vision framework** for on-device OCR. No cloud OCR, no per-image cost.
- Erg data comes from **photo OCR only**. No Bluetooth in v1.

---

## Prerequisites

- A Mac. SwiftUI means Xcode, and Xcode means macOS.
- **A physical iPhone from day one.** The Simulator has no camera, so nothing about the
  capture flow — the multi-cam session, preview layers, framing an erg monitor in real gym
  lighting — can be tested without hardware.
- Apple Developer Program membership ($99/yr) is **not** needed until TestFlight. Xcode's
  free provisioning installs builds on your own device with a 7-day expiry.

---

## How multi-user sync works

Phones never talk to each other. Each app is a thin client; Supabase owns the truth.

| Layer | Responsibility |
|---|---|
| iPhone | Capture, on-device OCR, local cache for instant feed open |
| Postgres | users, clubs, sessions, segments, test_results, daily_totals, social, moderation |
| Auth | Sign in with Apple + email |
| Storage | Two photos per post, served via CDN |
| Row Level Security | "You may only edit your own rows", enforced in the database |
| Edge Functions | Leaderboard rollups, push triggers |

Supabase over Firebase because leaderboards are aggregation queries.
`SUM(distance) GROUP BY user ORDER BY total DESC` is one line of SQL; in Firestore the same
thing needs counter documents and cloud functions kept in sync by hand.

### Two schema rules that are load-bearing

1. **Snapshot the category on each test result.** Novice/senior is self-declared and
   changeable at any time. If a leaderboard reads today's status, a rower switching to
   Senior silently rewrites their own history and empties the novice rankings. Store
   `gender_at_time` and `category_at_time` on the result row.
2. **Never compute leaderboards on request.** Write to a rollup table on a schedule and
   read that.

### Derived, not stored

- **The streak is computed from session dates**, never kept as a counter. A stored counter
  drifts the first time a post is deleted, backdated, or synced late from a second device.
- **All three profile charts read from one `daily_totals` table** — they are different
  renderings of the same rows, not three scans over `sessions`.

### OCR

Apple's Vision framework, on-device. Reading the digits is the easy half; knowing *which*
number is which is the hard half. The monitor lays out time, metres, split and rate in a
fixed grid, so match on the relative geometry of the bounding boxes, not the raw text.
Collect a test set of real monitor photos in varied lighting before writing any of it.

---

## Environments

Three build configurations, each pointing at different infrastructure.

| Configuration | Bundle identifier | Backend | Who runs it |
|---|---|---|---|
| Debug | `…rowingpals.dev` | Dev Supabase | You, on your own phone |
| Staging | `…rowingpals.beta` | Dev Supabase | TestFlight testers |
| Release | `…rowingpals` | Production Supabase | The App Store |

- Different bundle IDs mean all three install side by side. Give each a different icon and
  display name so you never demo the wrong one.
- Supabase URL and anon key live in per-configuration `.xcconfig` files, surfaced through
  Info.plist. Never hardcoded, never committed.
- **Two separate Supabase projects.** Dev and production, never shared.
- Seed the dev database with a fake club and ~20 fake rowers. You cannot judge a
  leaderboard against three rows of your own test data.
- Feature-flag anything half-built so it can ship dark.

---

## The release ladder

1. **Simulator** — layout and navigation only. Useless for camera work.
2. **Own device, free provisioning** — 7-day expiry, re-sign by rebuilding. Free.
3. **TestFlight internal** — up to 100 testers, each added as an App Store Connect user by
   Apple ID. No review; builds arrive in minutes. Requires paid membership.
4. **TestFlight external** — up to 10,000 testers per app by email or public link. Requires
   Beta App Review (usually a day). Up to six builds submitted per 24 hours. An internal
   group must exist before an external one can be created. Builds expire after 90 days.
5. **App Store** — full App Review.

---

## App Store requirements

### Guideline 1.2 — user-generated content (the one that rejects social apps)

Apps with UGC **must** include all four:

1. **A method for filtering objectionable material** from being posted — image moderation
   on upload, text filtering on captions and comments, before they go live.
2. **A mechanism to report offensive content**, with timely responses. A report control on
   every post and comment, feeding a queue that is actually read.
3. **The ability to block abusive users** — hides their posts, prevents interaction, both
   directions.
4. **Published contact information** — a real support email, reachable from the App Store
   listing and from inside the app.

Add a terms of service with an explicit zero-tolerance clause for objectionable content,
agreed at signup. Reviewers check for this on social apps specifically.

### Everything else

- **In-app account deletion is mandatory** (Guideline 5.1.1(v)) for any app supporting
  account creation. "Email us to delete your account" is a rejection.
- **Sign in with Apple** required if any other third-party login is offered.
- `NSCameraUsageDescription` in Info.plist, written as a real sentence. Without it the app
  crashes rather than being denied.
- Privacy manifest (`PrivacyInfo.xcprivacy`) plus App Privacy labels in App Store Connect.
- Listing assets: 1024px icon, screenshots at required device sizes, description, keywords,
  a support URL and a privacy policy URL — both must resolve.
- Age rating: UGC and social features land at 12+ or higher.
- UK/EU data protection: a real privacy policy and a lawful basis for processing. Account
  deletion covers much of the practical burden.

---

## Costs

| Item | Cost | When |
|---|---|---|
| Apple Developer Program | $99/yr | Only for TestFlight onward |
| Supabase free tier | £0 | Covers a club-sized beta |
| Supabase Pro | $25/mo | Only once storage or bandwidth outgrows free |
| Domain (privacy policy, support) | ~£10/yr | Before submission |
| Image moderation API | pennies/1k | Before submission |
| Push notifications (APNs) | £0 | Included with membership |

Under £100 for year one at club scale. The cost that scales is photo storage — downscale to
1600px on the long edge and compress before upload.

---

## Feature order

### v1 — everything needed to reach TestFlight

Auth + Sign in with Apple · Club directory and join · Dual-camera capture · OCR review
sheet · Multi-segment sessions · Water logging · Feed · Reactions and comments · Metres
leaderboard · Test leaderboards · Profile and PB board · Day streak with rest days · Weekly
volume bars · Consistency calendar · PB progression charts · Report / block / filter ·
Account deletion · Push plumbing

The streak and the charts are in v1 because they add no capture flow, no permissions and no
backend — they are queries and drawings over data the app already holds, and they are what
makes a profile worth revisiting between posts.

### v1.1 — first month after beta

Rank-change notifications, then crew tagging. Notifications first because the push
infrastructure already exists and it drives mid-week returns. Keep frequency low — one a
week beats one a day.

### v1.2 — before winter training

Challenges and events.

### v2 — once clubs are adopting, not individuals

Coach / captain view, then Season Wrapped. The coach view needs a roles and permissions
layer, which is why it waits — but one captain adopting brings forty rowers with them.

### Out of reach without Bluetooth

The shape *inside* a single piece — whether someone negative-split their 2k. Progression
over time is fine; per-split curves need data a summary photo does not contain.

---

## Timeline (solo, part-time)

| Weeks | Phase | Milestone |
|---|---|---|
| 1–6 | Swift and SwiftUI fundamentals | Throwaway apps, typed by hand |
| 5–10 | **Walking skeleton** | Sign in, photo, upload, visible on a second phone |
| 10–18 | OCR pipeline and review sheet | Reliable extraction on the photo test set |
| 16–26 | Feed, leaderboards, profile, social | Recognisably the design |
| 24–30 | Moderation, deletion, settings, empty states | Guideline 1.2 satisfied |
| ~28 | TestFlight internal | Five people using it |
| ~32 | TestFlight external | The club using it |
| 40+ | App Store submission | Public |

The two phases that reliably overrun are the OCR pipeline and the compliance work in
weeks 24–30.

---

## Working with Claude Code

- **Synchronised source folder** so files written to disk are compiled without touching
  project structure.
- **XcodeBuildMCP** so builds, simulator runs and screenshots happen in the loop rather
  than by hand.
- **Plan mode first** for anything non-trivial; one feature per branch; commit at every
  green build.
- **Make it verify**: "build it, run it, screenshot it, and tell me what differs from the
  brief" should end almost every UI request.

### Known limits

Claude Code cannot see your phone — only the simulator. Everything camera-related is tested
by you, on hardware, outside the loop. It reads compiler errors well and layout problems
badly. Swift compiles are slow and the tooling rebuilds fully. SwiftUI moves every year, so
check Apple's current documentation when something looks off.
