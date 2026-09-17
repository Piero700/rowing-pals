# Rowing Pals redesign — handoff v2
Captured: 2026-09-17

This **supersedes** `rowing-pals-redesign-handoff.md` (v1) — the user supplied an updated prototype
(`docs/design/rowing-pals-design-v2.html`, originally `/Users/piero/Downloads/rowing-pals-design(1).html`)
with several new features layered on. Read this file, not v1, before starting redesign work.
[[project_redesign_deferred]] still applies for sequencing context, but is now superseded on
*when* the redesign starts — see conversation: the user chose to start the redesign before task 19
(TestFlight), explicitly deferring 19 further ("I will do the test flight once I feel that the app
looks good and functions good").

Extracted by a full read of the prototype file (all 309 lines, dense embedded CSS/HTML/JS). The
file itself is layered — it reads as 3-4 progressive revisions concatenated (functions get
redefined later in the file; the LAST definition of anything is authoritative) — so treat this doc,
not a skim of the raw file, as ground truth.

## 1. Design tokens

The file has two overlapping `:root` blocks; the second (further down) wins. **Final effective
values:**

**Dark (default):**

| Token | Value | Role |
|---|---|---|
| `--bg` | `#09090b` | page background |
| `--base` | `#101114` | screen/card base |
| `--card` | `#1b1c21` | card surface |
| `--raised` | `#292c34` | raised/hover surface |
| `--line` | `#464a56` | borders |
| `--text` | `#f7f8fc` | primary text |
| `--muted` | `#bbc0ce` | secondary text |
| `--faint` | `#a3abba` | tertiary text |
| `--brand` | `#91b8ff` (blue) | **actions** — primary buttons, links, active nav |
| `--brand2` | `#315fba` | darker blue variant |
| `--brandSoft` | `rgba(145,184,255,.14)` | tinted backgrounds for brand |
| `--good` | `#78d7ac` (green) | **success only** — success screen, on-toggles. NOT achievement badges. |
| `--goodSoft` | `rgba(120,215,172,.12)` | |
| `--accent` | `#c6adff` (lilac) — new token | **records** — PB values, avatars, rank-hero |
| `--accentSoft` | `rgba(198,173,255,.12)` | |
| `--gold` | `#efc37c` (amber) — new token | **rank movement only** — the "↑ 2 places" indicator |
| `--goldSoft` | `rgba(239,195,124,.12)` | |
| `--warn` | `#ffc364` | barely used |
| `--bad` | `#ff766f` | destructive/error |
| `--r1/r2/r3` | `18px/24px/30px` | corner radii |
| `--glass` | `rgba(43,46,55,.86)` — new | floating glass nav bar / floating icon buttons |
| `--shadow` | `0 28px 75px rgba(0,0,0,.45)` | |
| `--tap` | `48px` | min tap target |

**Light (`html[data-theme="light"]`, final):**

| Token | Value |
|---|---|
| `--bg` | `#dfe3eb` |
| `--base` | `#edf0f5` |
| `--card` | `#ffffff` |
| `--raised` | `#dce2ec` |
| `--line` | `#949eae` (deliberately more visible than a naive dark→light scale) |
| `--text` | `#111723` |
| `--muted` | `#3e4c61` |
| `--faint` | `#4e5c70` |
| `--brand` / `--brand2` | `#214fa3` (same value for both) |
| `--brandSoft` | `rgba(33,79,163,.12)` |
| `--good` | `#176a4a` |
| `--accent` | `#67409b` |
| `--gold` | `#84500b` |
| `--glass` | `rgba(255,255,255,.94)` — near-opaque, not translucent, in light mode |
| `--warn` | `#9b5c00` |
| `--bad` | `#c93c36` |
| `--shadow` | `0 25px 65px rgba(31,37,58,.18)` |

**Explicit palette-roles comment in the CSS: "blue actions, lilac records, amber rank movement,
green success."** Confirmed by usage — `.rank-hero`, PB values, avatars, and the "New PB" badge
all render in accent/lilac, not green; green stays narrowly on the success screen and toggle
switches; gold is *only* the rank-change arrow.

This is a **four-accent-role system** (brand/accent/gold/good), replacing CLAUDE.md's current
binding "exactly 3 colours, one job each" rule (`Accent.signal`/`Accent.pb`/`Accent.live`). CLAUDE.md
needs updating as part of this work, not worked around.

Light mode gets hand-tuned overrides beyond the token swap: glass surfaces get an explicit border
+ stronger shadow instead of relying on translucency alone; primary buttons use a flat colour with
its own hover shade rather than the token default; active segmented/tab states use a flatter,
higher-contrast pair instead of the soft rgba tint. A `prefers-contrast: more` layer further
boosts muted/faint/line contrast and disables blur in both themes — worth carrying into SwiftUI as
a real accessibility consideration.

## 2. Screen inventory

Sidebar order: **01 Onboarding, 02 Activity feed, 03 Rankings, 04 Log workout, 05 Review session,
06 Profile, 07 Settings**, then **08 Other profile, 09 Find rowers, 10 PB history, 11 All personal
bests, 12 Clubs** (appended by later script layers, not in the original numbered list). No
grouping — a flat list. Additional views with no sidebar entry: `test-detail`, `post` (workout
detail), `comments`, `create-club`, `manage-club`, `success`, `people` (shared by
Following/Followers/Find-rowers).

**01 — Onboarding.** "Find your club" / "Your club powers your feed and team rankings. You can also
continue without one." Search field, club list (crest, name, member count, location, and a join
policy tag: "Open membership" vs "Approval required"), "I'm not in a club" text button, sticky
bottom CTA that names the selected club. Picking an approval-gated club sends a join request
("Join request sent" toast, "Join request pending" shown later on profile) instead of joining
immediately.

**02 — Activity feed** ("Your crew"). Segmented **Following / Club** — matches what's already
built (no Global). Feed cards: avatar-with-streak-fire, name (→ profile), club, dual-camera photo
(tap the inset to swap main/inset), 3-metric row, caption, a **workout-link row**
("UT2 · Main workout" / "12,000m · 47:28.8 · 3 splits" ›) that opens the full photo-first detail
screen rather than expanding splits inline, reactions (each emoji its own pressed pill + a "＋☺"
opening a 12-emoji picker sheet), and an actions row (comment count, share). Empty states for no
posts / no club.

**03 — Rankings.** Segmented **Volume / Test results**. A single "Filters" chip opens a sheet
(not inline chips) with **three independent axes**: Gender (All/Male/Female), Level
(All/Novice/Senior), and Scope (All/My club/Following) — all AND'd together. A caption line states
the composed filter, e.g. "All clubs · This week."
- *Volume*: a `rank-hero` card (your weekly volume, a live sentence — "You lead this group" /
  "Xm to move into #N" / "You are outside these filters" — and the overall leader's name),
  then a ranked list (crown for #1, gold left-border "winner" row, tinted "you" row, avatar with
  streak badge, name + club/level, right-aligned score).
- *Test results*: the existing 7-test grid (500m/1k/2k/5k/10k/30min/60min) **plus a trailing
  "+ Add test" tile** opening a form to define a new custom distance- or time-based test — the new
  board starts empty. Tapping a populated tile opens `test-detail`: same filter sheet, scored by
  fastest-time or furthest-distance per type, with a note "Illustrative results · Actual PBs
  remain on profiles."

**04 — Log workout / Capture.** Dual-camera composite: a large main tap target + a smaller inset
thumbnail. Controls: a "Swap cameras" (↔) button flipping which feed is main vs inset, the shutter
(center — takes/confirms both, proceeds to review), and a **corner-picker button** opening a sheet
with 4 explicit position choices (top-left/top-right/bottom-left/bottom-right) — inset position is
fully user-configurable, not fixed. Caption: "Front + rear · No time limit" — **no countdown timer
at all**, a deliberate departure from the current live-capture screen. A "Enter session manually"
escape hatch skips photo capture entirely and opens Review with blank fields.

**05 — Review session.** Big total at top. Distance/Time fields, **Average /500m now read-only,
auto-computed** as distance/time change, Stroke rate with an inline **Confirm button embedded in
the field** (mirrors the existing low-confidence-OCR pattern, but generalized: always required
here, not confidence-gated). New: a **"Main workout label" dropdown**
(UT2/UT1/Threshold/Intervals/Test/Recovery) applied to the main split's badge. Splits list
unchanged in shape. Caption field (relabeled "Caption"). New: a **photo strip** ("Add another
photo") for extra gallery photos beyond the two dual-camera shots, each removable. New: a
**Session type dropdown** (Training / 2k test / 5k test) — picking a test type validates the
entered distance matches (2000m/5000m exactly) and, if the time beats the existing PB, updates the
recorded PB and that test's leaderboard. "Include on leaderboards" toggle retained.

⚠️ **Flagged, not a spec to copy literally**: the prototype's data model keeps exactly one live
post per person (posting again silently replaces your only visible post, archiving the old one
under a throwaway key) — almost certainly a prototype simplification to avoid building a full
feed-history model in static HTML/JS, not an intentional product decision. **Confirm with the user
before building anything like this** — the real app already has a proper multi-post feed history
and there is no reason mentioned anywhere to collapse it to one post per user.

**06 — Profile** (own). Avatar (streak-fire badge if streak>0) + name + club/level. **`social-counts`**:
tappable "Followers"/"Following" pills with live counts → the shared people-list screen. A "Find
rowers" text button. If the viewer is private and has a pending request: a "Follow requests · N"
button. **Stats card is now 4-up**: weekly volume, session count, PB count, **streak days (new 4th
stat)**. Segmented **Overview / PBs / Posts**.
- *Overview*: a new **`profile-progress` block** — the existing 12-week volume bar chart
  (Monday-start axis, current week highlighted, tap-a-bar for a totals sheet, pager for older
  windows) plus the existing consistency habit grid (7×12, logged/today/future states, a
  "jump to a date" input, legend key) — both already exist in the current app (task 15), this
  just repositions them directly above "Recent activity." Then top PB cards (2k, 5k only) each
  linking to PB history, plus **prediction/estimate cards** for 2k and 5k.
- *PBs* tab: PB grid only (2-up), "View all" → `all-pbs` (flat list of every test with a result).
- *Posts* tab: shows a single workout-link to the latest post — same "one active post"
  simplification flagged above; needs confirming, not copying as-is.

⚠️ **Prediction/"estimate" cards are explicitly a placeholder.** The prototype's own copy says
"Illustrative training estimate · Algorithm preview," and its code comment states outright no
training model is implemented — it's a stand-in UI for a future algorithm. **Do not build a real
prediction algorithm from this** — at most, build the card's UI/copy pattern and leave the actual
number unimplemented or explicitly marked as a placeholder, and confirm scope with the user before
doing even that much.

Club section at the bottom: "Manage your club" (owners) / "Your club" / "Join or create a club".

**07 — Settings.** Sections: **App icon** (3 colour swatches — "Lagoon"/"Midnight"/"Pearl" — with a
rowing-oars glyph; real iOS alternate-icon support would be the actual implementation, not a CSS
demo), **Appearance** (Dark/Light — already exists), **Units and display** (Distance Metres/km
toggle — ⚠️ conflicts with CLAUDE.md's current hard rule "UI copy uses UK English: metres, not
meters" and fixed-metres-only display, needs a decision, not a silent override; **"Pace shown as"
Split/Watts toggle — new**, display-only), **Notifications** (Comments & replies / Personal bests /
Club activity as three independent toggles, plus a "Quiet hours 22:00–06:30" row — placeholder
only in the prototype), **Privacy** (**new** — "Profile visibility: Public/Private" opens a real
sheet toggling a private-account flag with explanatory copy; "Who can comment: Following" —
placeholder), **Account** (Edit profile, "Export your metres" CSV — **prototype has zero JS wiring
for this, it's a placeholder despite reading like a real feature**, Log out), and a full-width
**Delete account** button (already exists, task 18). Version string footer.

**08 — Other rower's profile** (dynamic). Same shape as own profile, read-only: avatar/name/club, a
Follow/Following/Requested/"Follow back" button whose label/style reacts to relationship state,
social counts, and — **if the viewer isn't approved to see a private account** — a `private-card`
("This profile is private / Send a follow request to see their stats, personal bests, followers
and following.") instead of stats. If visible: weekly stats, 2 PB cards, and an "Overall rankings"
mini-card (volume rank / 2k rank / 5k rank).

**09 — People list** (shared for Followers / Following / Find rowers). Search field + a flat list
of rows (avatar, name+club, Follow-state button unless it's you).

**10 — PB history.** Opened from any PB card anywhere. Owner name + "Sample history" caption. A
summary card (current best, date, "+N faster/further" gain badge); for your own 2k/5k, the
prediction/estimate card sits above it. A 3-button period control (3 months / 6 months / All time).
A **scrubbable SVG line chart**: gridlines with value labels, filled area under the line, a
draggable vertical guide, dots per point (selected one enlarges/recolors to accent), driven by
pointer drag directly on the chart, kept in sync with a paired range slider and prev/next buttons.
Below: a dated list of every result, most recent first, each tappable to jump the chart, with
"Current PB"/"Personal best" sublabels. This is a genuinely interactive, real chart component, not
a static image — expect real SwiftUI/Swift Charts drag-gesture work here.

**11 — All personal bests.** Flat grid of every test with a result, each → PB history.

**12 — Clubs.** `club-options`: "Find a club to join," "Create a club," "Continue without a club."
`create-club`: real form (name, description, location, "Who can join?" open/approval/invite, "Club
focus" dropdown) — submitting makes you owner. `manage-club` (**owner-only** — a non-owner tapping
in gets a toast and nothing else): club summary, join-requests section (accept/decline), members
list with per-member role (member/admin/co-owner) editable via a sheet, remove-member flow with
its own confirm sheet, "Invite a rower," and a demo-data seeding button (dev-only, not a real
feature).

**Other views**: `test-detail` (per-test leaderboard, described above under Rankings).
`post`/workout-detail was rebuilt into a photo-first "hero" layout (§3). `comments` is a dedicated
full-screen thread, separate from the few inline comments already shown on the hero screen — reached
when a post has more comments than fit inline. `success` — checkmark, headline, a sentence that now
also states whether the session was included in rankings, "View in feed" CTA (mostly unchanged from
the current app).

## 3. Notable new components

- **App icon picker**: 3 solid-colour swatches with an oars glyph, radio-style selection. Real
  implementation = iOS alternate app icons (`CFBundleIcons`/`setAlternateIconName`), not anything
  CSS-related — a genuinely new platform integration, not just a settings row.
- **Private accounts + follow requests**: confirmed real, not just styling — a private flag gates
  profile visibility; following a private account creates a pending request instead of an
  immediate follow; the owner sees a request count and an accept/decline sheet. **This needs real
  schema work**: `profiles.is_private`, a `follow_requests` table (or a `status` column on
  `follows`), and RLS/query changes almost everywhere `follows` is currently read (task 16's
  following-scope logic, this session's `resolvedVisibilityFilter()`, profile-visibility checks).
- **PB history + scrub chart**: a real interactive line chart — pointer drag, a paired range
  slider, and tappable list rows all drive one shared "selected point" state. The existing
  PB-progression chart (task 15) is the starting point but this is a substantially richer
  interaction model (drag-to-scrub) than what's built today.
- **Prediction/estimate card**: placeholder for a future algorithm — see the warning under Screen
  06. Don't build the algorithm; can build the UI shell if the user wants it, once confirmed.
- **Streak fire badge**: a small 🔥 chip overlaid top-right on any avatar with a nonzero streak —
  appears everywhere avatars appear (feed, rankings, profile, person rows), not profile-only. This
  is new UI for data (`current_streak`) the app already computes (task 15) — a comparatively cheap,
  high-value addition.
- **Weekly volume chart + consistency habit grid**: both already exist in the current app (task
  15's `WeeklyVolumeChart` and `ConsistencyCalendarView`) — the prototype just repositions them
  and adds a tap-a-bar totals sheet, a "jump to a date" input, and pagination to older windows.
  Treat as an enhancement of existing components, not new ones.
- **Workout-hero photo-first detail**: a real, different layout from the current `PostDetailView`
  — full-bleed dual-camera photo at the top with a floating back button and a glass "person pill"
  (avatar+name+chevron → their profile) over it, then the rest (totals, a collapsible split
  breakdown, reactions, caption, an optional extra-photo gallery, up to 3 inline recent comments,
  sticky composer) scrolls up under a rounded sheet-lip edge. More Instagram-like than the current
  screen.
- **Dual-camera with a 4-corner, user-configurable inset**: confirmed genuinely configurable, not
  fixed — a corner-picker sheet with 4 explicit buttons, reused (with different fixed/adjustable
  defaults) across the feed card, the capture screen, and the workout-hero detail. A separate
  "swap cameras" control flips which physical camera is main vs inset, independent of corner
  choice. This is a real departure from the current single-fixed-corner selfie inset.
- **Social counts, person-row, member-row**: tappable follower/following counters; a shared flat
  person-list row (social lists + directory search); a distinct member-row for club management
  (adds a role sublabel and a Manage/"You" trailing element).
- **Sheet/dialog**: the app's universal secondary surface (native `<dialog>` styled as a
  bottom/center sheet), reused everywhere: rankings filters, privacy toggle, follow requests,
  emoji picker, camera corner picker, share-workout preview, custom test creation, club
  member-role editor, remove-member confirmation, volume-chart week-total popup, habit-grid
  day-detail popup, and a generic **"Preview action"** fallback ("This action needs the native app
  connection...") for any control the prototype doesn't actually wire up. The prototype is explicit
  about which flows are real vs. stubs via this fallback — useful signal for what's genuinely
  specified vs. what's just a placeholder row.
- **Custom test creation**: a real (if minimal) feature — validates the label doesn't already
  exist, derives a display label ("750m"/"3k"/"20 min") from the input, starts the new board empty.
- **CSV export**: reads as a real settings row but has **zero JS wiring** in the prototype — treat
  as "there should be an export entry point," not a specified export format/flow.

## 4. Navigation structure

**Not one unified tab bar.** Two separate floating glass elements: a pill-shaped 3-column group —
**Feed / Rankings / Profile** — and a separate circular **Log** button beside it (brand-blue,
jumps straight to capture). This extends the current app's "Post sits outside tab selection"
pattern (already true today) into two visually distinct glass capsules rather than a 4th slot in
one bar. **Settings has no bottom-tab or top-level entry point shown in this prototype** — it's
presumably still reached from Profile, matching the current app.

This is a genuine IA change from the current 5-tab bar (Feed/Metres/Post/Tests/Profile) — Metres
and Tests collapse into one **Rankings** tab with an internal Volume/Test-results toggle, matching
[[project_redesign_deferred]]'s v1 note about this same merge.

## 5. Behavior worth knowing from the prototype's JS (not just markup)

- The file is layered — later function redefinitions win. Built from this doc, not a fresh raw
  read, that's already accounted for.
- Rankings filtering composes **three independent axes simultaneously** (gender × level × scope),
  all AND'd.
- Club roles: `member` / `admin` / `co-owner` / `owner` — only `owner` can reach club management.
  Join policies: `open` / `approval` / `invite`.
- Streak values in the prototype are hardcoded per-person, not derived from date logic — no new
  insight into streak semantics beyond what task 15 already built.

## 6. Open questions to resolve with the user before/while building

These are called out inline above too, collected here so they're not missed:

1. **"One live post per user"** (Screens 04/06) — confirm this is a prototype simplification, not
   a real request to collapse the feed to one post per person.
2. **Prediction/estimate cards** — confirmed placeholder for an unbuilt algorithm; confirm whether
   to build the UI shell now (with a placeholder number/copy) or skip entirely until there's a real
   algorithm to back it.
3. **Metres/km toggle** — conflicts with CLAUDE.md's current fixed-metres, UK-English hard rule;
   needs an explicit decision (keep metres-only, or actually support a unit toggle end-to-end).
4. **CSV export** — needs actual scope (what columns, what format) since the prototype specifies
   only that a row should exist.
5. **Four-accent-role palette** — CLAUDE.md's binding 3-colour rule needs a real update to
   brand/accent/gold/good, not a workaround; the exact hex values above are ready to drop in.
6. **Private accounts** — real schema work (`is_private`, follow-request status) touching several
   already-built features (task 16 following, this session's post-visibility, any profile view) —
   worth scoping as its own early phase given how many existing files it touches.

## 7. Suggested phasing (proposed, not decided — see conversation for what the user picked)

Given the size of this — tokens/IA, private accounts + follow requests, streak badges, profile
progress repositioning, PB history scrub chart, workout-hero detail rebuild, dual-camera
configurable corner, clubs (create/manage/roles/requests), settings overhaul, custom tests, and
rankings filter sheet all being independently substantial — this should NOT be attempted as one
pass. A phased, task-branch-per-phase approach (matching the existing `.claude/skills/rp-task`
workflow) is strongly recommended over one giant redesign task.
