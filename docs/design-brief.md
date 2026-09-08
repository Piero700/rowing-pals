# Rowing Pals — iOS App Design Brief

**How to use this:** paste this whole document into Claude Design. It is written as a design prompt, not a spec document — every section is an instruction.

---

## 1. What you are designing

**Rowing Pals** is an iOS social app for rowers. It is Instagram's feed and Strava's leaderboards, applied to one sport only, with a BeReal-style honesty mechanic at its centre.

The core ritual: you finish a piece on an erg, open the app, and shoot **two photos at once** — the rear camera captures the ergometer monitor, the front camera captures your face or the boathouse around you. Both go into one post. An algorithm reads the numbers off the monitor photo, so the post fills in its own distance, time, split and stroke rate. Those extracted numbers flow straight into the leaderboards.

That single mechanic is what makes the app work: the leaderboards are trustworthy because every number on them came off a photo of a real monitor, taken live.

Design 8 screens covering the full core flow.

---

## 2. Visual direction — iOS 27, Liquid Glass, minimal

This should look like a native app built for the current version of iOS, not a themed web app. Follow Apple's Liquid Glass material system as refined in iOS 27:

- **Layered translucency.** Controls and bars are a glass material floating *over* content, not a solid band butted against it. Content is visible through them, diffused and blurred rather than merely tinted.
- **Darkened edges and specular highlights.** Every glass element carries a subtly darkened outer edge and a bright specular highlight along its upper rim. This is what separates a glass surface from a flat translucent rectangle — do not skip it.
- **Content diffusion over transparency.** Glass over a busy photo should heavily diffuse what is behind it. Legibility wins over showing off the effect. Where text sits on glass over an image, add a scroll-edge scrim so the text never fights the photo.
- **Concentric, generously rounded geometry.** Corner radii nest concentrically — inner elements have proportionally smaller radii than the containers holding them.
- **Minimal chrome.** No borders, dividers, drop shadows or card outlines except where glass edges provide them. Separation comes from material, spacing and type weight.

### The bottom bar (called out because you asked for it specifically)

The tab bar is a **separate, floating, interactive glass capsule** — detached from the bottom edge of the screen, with content visibly scrolling underneath and through it. It is not a docked bar.

- Free-floating pill with margin on all sides, sitting above the home indicator
- Heavy background blur, darkened edge, specular top rim
- **It shrinks on scroll down** into a compact pill showing only the active tab's icon, and **expands back to full width on scroll up** — the bar is a live element that responds to the user
- The centre **Post** button is raised and visually distinct: a filled accent circle breaking the capsule's top edge, the only saturated element in the bar

Show the bar in both its expanded and shrunk states across your screens so the behaviour is legible.

### Palette

Design **dark mode as the hero** — rowers train at 6am and in dim gyms, monitor photos read better against dark, and glass materials are at their best over dark ground. Provide light mode as a second pass on at least the feed and one leaderboard.

| Role | Value | Use |
|---|---|---|
| Base (dark) | `#0A0C0F` graphite | App background |
| Base (light) | `#F6F6F7` | Light mode background |
| Glass fill | white 10–16%, blur 40–60 | Bars, sheets, chips |
| Glass edge | white 22% top rim, black 30% outer | Specular + darkened edge |
| Primary text | `#FFFFFF` / `#0A0C0F` | — |
| Secondary text | 60% opacity of primary | Metadata, labels |
| **Accent — Signal Cyan** | `#3AD7E5` | Interactive elements, active tab, links, the Post button |
| **Accent — PB Gold** | `#F5C542` | *Reserved exclusively* for personal bests and podium ranks 1–3 |
| **Accent — Live Coral** | `#FF6B5A` | *Reserved exclusively* for the live capture state and the countdown window |

Three accents, each with one job. Nothing else is saturated. If a colour appears somewhere its role doesn't cover, that is a bug.

### Typography

SF Pro throughout. The critical rule: **all numbers use tabular (monospaced) lining figures.** Splits, times, ranks and distances stack in columns constantly in this app, and proportional digits will make every leaderboard look broken.

- Display numerals (session total, PB times): large, tight tracking, `-0.02em`
- Body: 17pt regular, secondary 15pt
- Labels, badges, category chips: 11–12pt, uppercase, `+0.06em` tracking, semibold

---

## 3. The data model, so labels are correct

An erg monitor (Concept2 PM5) shows: **elapsed time**, **metres**, **/500m split** (pace, the number rowers actually care about), **s/m** (stroke rate), watts, calories and drag factor. Extract and display the first four; treat watts and calories as optional detail.

A **session** contains one or more **segments**. Each segment is one monitor photo, tagged Warmup / Main / Cooldown / Extra. The session card shows the **combined total** on top, with a breakdown of segments underneath. Only a segment tagged **Main** is eligible to become a test result.

Session types:
- **Erg** — must be shot live in-app, dual camera, no gallery upload, within a capture window after finishing. Earns a `Photo-verified` badge.
- **Water** — logged any time, manual distance and time, optional photo. Carries a `Logged later` marker and never gets the verified badge.

Categories: **Novice** and **Senior** are experience levels in UK university rowing, not ages — a novice is in their first season. Self-declared, changeable at any time. **There is no weight class anywhere in this app.**

**Streaks** are day-based with two rest days per week that hold the run automatically. Every progression chart in the app is built from session summaries — one session, one data point — so nothing here needs per-stroke data.

---

## 4. Navigation

Five tabs: **Feed · Meters · [Post] · Tests · Profile**

---

## 5. The screens

### Screen 1 — Onboarding: find your club

The user has just signed up. Full-bleed dark background, a large searchable list.

- Title: "Find your club"
- Prominent glass search field, focused, with "UEA" typed in
- Results as glass rows: club crest placeholder, club name, member count, location. Show: **UEA Boat Club** (48 members, Norwich), **UEA Novice Squad** (31 members, Norwich), **Norwich Rowing Club** (86 members, Norwich)
- A secondary row at the bottom: "Can't find it? Create a club" and "Join with an invite code"
- Below the fold, indicate the remaining setup: name, gender (used for leaderboard splits), and a **Novice / Senior** segmented control with a one-line explainer: "Novice means you're in your first season. You can change this any time."

### Screen 2 — Feed (Home)

The main tab. Vertically scrolling cards, edge-to-edge photos, glass everything else.

**Card anatomy:**
- **Header row:** avatar, display name, club name and category chip (`SENIOR · M`), time ago on the right
- **Media:** the erg monitor photo fills the card, with the front-camera selfie as a small rounded inset in the top-left corner — tappable to swap which is primary, exactly like BeReal
- **A glass data strip overlaying the bottom of the photo:** total distance in large tabular numerals, then time, avg split, avg rate as a row of smaller labelled values
- **Segment chips** beneath: `WARMUP 2,000m` · `MAIN 12,000m` · `COOLDOWN 2,000m`, tappable to expand into per-segment detail
- **Verification badge:** small `✓ Photo-verified` chip in cyan, or `Logged later` in neutral grey for water sessions
- **Reaction row:** 4–5 tap reactions with counts, plus a comment count

**Show three cards** demonstrating the range:
1. **Piero Ciobanu** · UEA Boat Club · SENIOR M · 3 min ago — "Steady state + rate ladder", **16,000m · 1:04:50 · 2:01.6 · r19**, three segments, photo-verified, 12 reactions
2. **Alice Whitfield** · Durham University BC · SENIOR W · 1h ago — a **2k test**, **2,000m · 7:04.1 · 1:46.0 · r34**, single Main segment, with a **gold `PB` flag** on the card — this is the moment the app exists for, make it feel like an event
3. **Sam Okonkwo** · UEA Boat Club · NOVICE M · yesterday — a **water session**, 14.2 km · 1:12:00, photo of a boat on the river, `Logged later` marker, no split shown

Piero's three segments, if you need the detail: Warmup **2,000m · 8:33.2 · 2:08.3 · r18** · Main **12,000m · 47:28.8 · 1:58.7 · r20** · Cooldown **2,000m · 8:48.0 · 2:12.0 · r17**.

Header of the feed: a scoped title with a segmented glass control — **Following / My Club / Global**.

### Screen 3 — Capture

The live dual-camera screen. This is the app's signature moment, so treat it as the most designed screen in the set.

- Full-bleed rear camera viewfinder framed on an erg monitor
- Front camera inset preview in the corner
- **A capture window countdown in Live Coral** at the top — a slim progress arc or bar with remaining time, e.g. "8:42 left to post"
- Single large capture button, centred, glass ring around a solid core
- A small caption under the shutter: "Both cameras fire at once"
- **No gallery access affordance anywhere** — its absence is the point, and the design should make that feel intentional rather than missing
- A secondary, quieter entry point at the bottom edge: "Log a water session instead"

### Screen 4 — Session review sheet

Where the extracted data gets confirmed. A tall glass sheet over the dimmed capture screen.

- Title: "Check your numbers"
- **The session total at the top**, large: `16,000m · 1:04:50 · 2:01.6 /500m · r19`
- Below it, **each segment as an editable row**: a thumbnail of that monitor photo on the left, then the four extracted values as inline-editable fields, then a **segment tag selector** (Warmup / Main / Cooldown / Extra)
- Any field the algorithm read with low confidence gets a subtle cyan underline and is pre-focused for checking — do not use error red, this is normal and expected, not a failure
- **`+ Add another photo`** row at the bottom of the segment list, since a session can have several
- **A test-detection prompt**, appearing as a distinct highlighted glass block when the Main segment matches a standard distance: *"This looks like a 2k test. Add it to the 2k leaderboard?"* with Yes / No. Nothing enters the rankings without this tap.
- Caption field, then a full-width **Post** button

### Screen 5 — Meters leaderboard

- Title **Meters**, with a glass segmented control for **Week / Month / Year**
- A second row of filter chips: **Male / Female** (the only split on this board), and a source toggle **All / Erg / Water**
- A scope selector matching the feed: Following / My Club / Global
- **Top three** get a distinct treatment — larger rows or a podium block, rank numerals in PB Gold
- **Ranked rows:** rank numeral, avatar, name, club, and the metre total in large tabular numerals on the right, with a thin two-tone bar underneath each row showing the erg/water split of that total
- **The user's own row is pinned above the tab bar as a persistent glass bar**, always visible however far they scroll — "You · 3rd · 116,250m"

Sample (Week, Male, All):

| # | Name | Club | Metres |
|---|---|---|---|
| 1 | Tom Ashworth | Newcastle University BC | 128,400 |
| 2 | Jack Fenwick | Durham University BC | 121,900 |
| 3 | Piero Ciobanu | UEA Boat Club | 116,250 |
| 4 | Marcus Reilly | UEA Boat Club | 104,800 |
| 5 | Sam Okonkwo | UEA Boat Club | 41,300 |

### Screen 6 — Test leaderboards

Two levels, and you should show **both** — the distance picker and one open distance.

**Level A — distance picker.** A grid of glass tiles, one per distance: **500m · 1k · 2k · 5k · 6k · 10k · 4min · 30min · 60min**. Each tile shows the distance large, and underneath, *the user's own PB for it* in small text — so the picker doubles as a personal scoreboard. Tiles for distances with no PB show a quiet "—".

**Level B — an open distance (design the 2k).** This is the drill-down structure you specified:

- Two levels of glass segmented control stacked: **Male / Female** on top, **All / Novice / Senior** below it
- So the user can view "Men overall" or narrow to "Novice men", and the header states plainly which view they're in
- Ranked rows: rank, avatar, name, club, **time in large tabular numerals**, with the **/500m split underneath in secondary text**, and the date of the result
- Category chip on each row when viewing All, so you can see who's a novice in the combined list
- Only each rower's **best** result per distance appears — one row per person
- Gold treatment on ranks 1–3, and a gold `PB` flag on any result set in the last 7 days

Sample (2k · Male · All):

| # | Name | Club | Time | Split | Cat |
|---|---|---|---|---|---|
| 1 | Tom Ashworth | Newcastle University BC | 6:04.2 | 1:31.0 | SENIOR |
| 2 | Jack Fenwick | Durham University BC | 6:11.7 | 1:32.9 | SENIOR |
| 3 | Piero Ciobanu | UEA Boat Club | 6:18.9 | 1:34.7 | SENIOR |
| 4 | Marcus Reilly | UEA Boat Club | 6:31.5 | 1:37.9 | SENIOR |
| 5 | Sam Okonkwo | UEA Boat Club | 6:52.4 | 1:43.1 | NOVICE |
| 6 | Ollie Grant | UEA Boat Club | 7:05.2 | 1:46.3 | NOVICE |

Female equivalents, if you need them: Alice Whitfield 7:04.1 (1:46.0) SENIOR · Nina Bergström 7:12.8 (1:48.2) SENIOR · Freya Lomax 7:48.9 (1:57.2) NOVICE.

### Screen 7 — Profile

The profile does two jobs: it says who this rower is (their PBs) and it shows whether they are actually turning up (their consistency). Design it in this order.

**a) Header** — avatar, name, club, category chip, Follow or Edit button. Deliberately small.

**b) The streak block.** A day streak with rest days built in, and the rest-day mechanic must be visible or it reads as a bug when a missed day doesn't break the run:

- Large streak numeral, e.g. **`23`** with the label "day streak"
- Beneath it, a row of small pips showing the week's rest allowance — **2 rest days per week**, resetting Monday. Filled pips are spent, hollow pips remain: `● ○` with the caption "1 rest day left this week"
- A rest day is **consumed automatically** when a day passes with no session. The user never declares one — they'd forget, and the streak would break for the wrong reason.
- The streak only breaks when a day passes with no session *and* no rest credit left
- Any logged session keeps the streak alive, erg or water, whatever the distance

**c) Season strip** — total metres this season, sessions logged, longest streak.

**d) The PB board.** A grid of glass tiles, one per test distance: distance label, time in large tabular numerals, split beneath, date. Empty distances are quiet dashed tiles inviting an attempt. Any PB set in the last 30 days carries the gold flag.

**Tapping a tile expands it into that distance's progression chart** — a line of every attempt over time, so the chart is the natural drill-down of the tile rather than a separate section competing for space.

> **Critical:** on a time-based chart, faster is a *lower* number, but every reader instinctively reads *up* as better. **Invert the y-axis** so the line climbs as the rower gets quicker. Mark each point that set a PB in gold, leave the rest in cyan, and annotate the current best.

**e) Weekly volume bars.** Twelve weeks of metres as a bar chart, with the rower's weekly target as a dashed line across it. Current week in cyan, past weeks muted. Tabular numerals on the axis. This is the honest counterpart to the streak — gaps are visible instantly.

**f) Consistency calendar.** A GitHub-style grid, 7 rows (Mon–Sun) by 26 weeks fitted to screen width, horizontally scrollable back through the season. Each square shaded in four steps of the cyan ramp by that day's volume; days with nothing are a faint empty square. Month labels above the grid. This shows patterns nothing else does — the Christmas gap, the exam dip, a good winter block.

**g) The photo grid** — 3-across thumbnails of their posts, each with a small distance overlay.

Show Piero's board: 500m **1:28.4** · 1k **3:02.6** (1:31.3) · 2k **6:18.9** (1:34.7) · 5k **17:12.4** (1:43.2) · 6k **20:54.8** (1:44.6) · 10k **35:48.0** (1:47.4) · 30min **8,410m** (1:47.0) · 60min **16,220m** (1:51.0) · 4min **—**

For the expanded 2k progression chart, plot his history: 6:41.2 (Oct) → 6:33.8 (Dec) → 6:35.1 (Feb) → 6:26.4 (Mar) → 6:18.9 (May, current PB). Four of those five are PBs, so four gold points and one cyan.

### Screen 8 — Post detail

One post, opened.

- Media full-bleed at the top, selfie inset, tap-to-swap
- Full session breakdown below: total, then **every segment as its own row** with its photo thumbnail, distance, time, split and rate
- If it was a test, a **gold result banner**: "2k test · 7:12.8 · Personal best · 3rd overall, 1st novice women"
- **Reaction row** — a horizontal set of tap reactions with counts. Use rowing-flavoured meaning rather than generic likes: fire (a PB), a grimacing face (a brutal piece), clapping hands (respect), an eyes emoji (watch this), and a plus button opening more
- **Comment thread** beneath: avatar, name, comment, timestamp, in glass rows. Write real comments a rowing crew would actually leave — "that's a 4 second PB, well in", "rate 33 is criminal", "see you at 6am"
- A glass composer pinned above the floating tab bar

---

## 6. States worth including if there's room

- **OCR uncertain** — the review sheet with two fields flagged for checking, and an "I'll type it in" fallback
- **Empty novice leaderboard** — "No 2k results here yet. Be the first." with a Post CTA, so thin categories feel like an invitation
- **Post success** — a brief celebratory moment when a post enters a leaderboard: "You moved to 3rd this week"

---

## 7. Guardrails

- **Do not** make this look like Strava. No orange, no dense stat dashboards, no map-first layout.
- **Do not** use flat translucent rectangles and call them glass. Edge darkening and specular highlights are what make the material read.
- **Do not** dock the tab bar to the screen edge. It floats, and it reacts to scroll.
- **Do not** use proportional figures for any number.
- **Do not** invent weight classes, kudos, badge systems, or ads.
- **Do not** design the streak to shame. A spent rest day is neutral information, not a warning — no red, no alert icon, no "don't lose your streak!" copy. Rest is training.
- **Do not** plot a time-based progression chart without inverting the y-axis. Getting faster must read as going up.
- **Do not** let Signal Cyan, PB Gold or Live Coral appear outside their assigned roles.
- Every number you place must be internally consistent: split × distance must equal the time shown. A rower reads these instantly and a wrong split will be the first thing they notice.
