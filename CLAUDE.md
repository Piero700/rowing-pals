# Rowing Pals

An iOS social app for rowers. Users post a training session as two simultaneous photos
(rear camera on the erg monitor, front camera on themselves), an on-device algorithm reads
the numbers off the monitor photo, and those numbers feed the feed, the profile and the
leaderboards.

**Erg only.** The app logs indoor erg sessions read from the monitor photo — nothing else. On-water
logging was removed (decision 54, 2026-10-14) and is not to be built unless the user asks for it
again (it may return later if rowers ask for it). Older docs that mention water sessions, an
erg/water split or a Water leaderboard filter are superseded.

## How to work on this project — read first

- **Build exactly what the user asks for, in full.** No reduced scope, no "simpler version",
  no stubbed parts presented as done, no silently skipped requirements, no substituting your
  own idea for theirs. If something in a request is genuinely impossible or conflicts with
  another rule, say precisely what and why *before* building, propose the closest full
  alternative, and let the user decide. Never quietly compromise.
- **The user's latest instruction overrides anything written in this file or in `docs/`.**
  That includes the design. If they ask for a change to the look, layout, colours or a
  feature, do it, then update the relevant doc so the files match the app again.
- Ask before building anything the user has not asked for.

## Read these first

- `docs/design/v4/` — **the latest canvas (2026-10-05)**: the app as built plus the Coaching
  section and updated Rankings/Settings screens (decisions 34–38). Where a screen is in v4, v4
  wins over v3. Build order in `docs/design/coaching-build-plan.md`.
- `docs/design/rowing-pals-v3-spec.md` + `docs/design/v3/` — **the current design (v3,
  2026-09-25), the visual source of truth for look, sizing and layout.** Exact per-screen
  values are in `docs/design/v3/RP Screen.dc.html`. **Read the relevant section before
  building any UI.**
- `docs/design/v2-decisions.md` — product decisions; they win over any prototype.
- `docs/design/rowing-pals-redesign-handoff-v2.md` — v2 spec, still the reference for
  features and behaviour v3 doesn't redraw.
- `docs/design-brief.md` — older screen-by-screen brief. Where it disagrees with the v2
  handoff, the handoff wins.
- `docs/build-plan.md` — sequencing, environments, App Store requirements.

## Stack

- SwiftUI, targeting current iOS (Liquid Glass design system)
- Supabase — Postgres, Auth, Storage, Realtime
- Vision framework for on-device OCR (no cloud OCR, no per-image cost)
- No third-party UI libraries. If a component seems to need one, ask first.

## Hard rules — never do these

- **Never hand-edit** `Rowing Pals.xcodeproj/project.pbxproj`. Source files go in the
  synchronised folder and Xcode picks them up. If a file isn't being compiled, say so
  rather than editing project structure.
- **Never hardcode** a Supabase URL, anon key, or any secret. They come from the
  `.xcconfig` for the active build configuration, surfaced via Info.plist.
- **Never commit** an `.xcconfig` containing real keys. They are gitignored.
- **Never point a Debug build at the production Supabase project.**
- **Never hardcode a colour, font size or spacing value in a view.** Every visual value
  comes from a token in `DesignSystem/`, so a redesign is a change in one place.
- **Never use proportional figures** for any number the user reads. Every numeral in this
  app sits in a column with other numerals at some point.
- **Never force-unwrap** outside of tests.

## Design system

The design is **current, not permanent**. Since decision 42 the type scale and spacing follow
the v4 canvas (Apple's iOS sizes, 8-point grid); the palette below is unchanged. The values below describe the v2 design
(captured 2026-09-17, full spec in `docs/design/rowing-pals-redesign-handoff-v2.md`). When
the user changes the design, update `DesignSystem/` and the docs; do not treat this section
as a reason to refuse.

Structure that should survive any redesign:

- All colours, radii, spacing and type styles are named tokens in `DesignSystem/`. Views use
  tokens only. Each accent colour has one job; a colour outside its job is a bug.
- Dark mode is the primary design. Light mode must work but is secondary.
- Typography: SF Pro. **All numerals use `.monospacedDigit()`.**
- **Every screen swipes back from the left edge** (decision 61). Push new screens through the
  navigation stack (an `AppRoute` in `RouteHost`) or present full-screen areas through `RouteHost`,
  and the swipe comes for free (`App/SwipeBackNavigation.swift`, `edgeSwipeToDismiss()`); never
  turn it off.
- **Grouped rows (decision 97, on trial):** setting or editing a land session uses the compact grouped-rows
  style (`DesignSystem/GroupedForm.swift`, `Tokens.Grouped`): one card per group with 12 pt corners and a hairline
  edge, 44 pt rows with the label left and the value right. The user will decide whether the rest of the app follows.
- **Helper text is marked, not hard-coded (decision 98):** explanatory notes and hints use `.guidance()` (or
  `GuidedText` for an empty state's hint) from `DesignSystem/Guidance.swift`, so they hide after 7 days of use or
  when turned off in Settings. Never mark errors, empty-state facts or anything needed to use a screen.
- **Every workout time is typed with `DurationTextField`** (decisions 53, 56): digits only, the colon
  put in as you type.

**Liquid Glass is a permanent requirement**, whatever else changes. Glass surfaces carry a
darkened outer edge and a specular top rim — a flat translucent rectangle is not glass.
The tab bar floats detached from the screen edge, shrinks on scroll down and expands on
scroll up. Content scrolls under it. Respect Increase Contrast / Reduce Transparency with
a more opaque fallback.

Current v2 palette (dark / light):

| Token | Dark | Light | Job |
|---|---|---|---|
| `Accent.brand` | `#91B8FF` | `#214FA3` | Interactive elements, active tab, links, the Log button (solid), Settings switches |
| `Accent.records` | `#C6ADFF` | `#67409B` | Personal bests, avatars, the rank-hero card |
| `Accent.rank` | `#EFC37C` | `#84500B` | The #1 leaderboard row and rank-movement indicators |
| `Accent.success` | `#78D7AC` | `#176A4A` | Success confirmation; the Review screen's "Include on leaderboards" switch |
| `Accent.verified` | `#91B8FF` | `#214FA3` | The verified-club tag beside a club's name (decision 98); brand blue's value, its own role |
| `System.error` | `#FF766F` | `#C93C36` | Error/destructive text and controls |
| `Ink.primary` / `.secondary` / `.faint` | `#F7F8FC` / `#BBC0CE` / `#A3ABBA` | `#111723` / `#3E4C61` / `#4E5C70` | Text levels |
| `Base` | `#101114` | `#EDF0F5` | Screen/card ground |
| `Surface.card` / `.raised` / `.line` | `#1B1C21` / `#292C34` / `#464A56` | `#FFFFFF` / `#DCE2EC` / `#949EAE` | Card levels and borders |

## Domain vocabulary — use these exact words in code and UI

Naming drift across sessions is expensive. These are the terms:

- **split** — pace per 500 metres, stored as `split_ms: Int`. Never "pace".
- **rate** — strokes per minute. Never "cadence", never "spm" in identifiers.
- **piece** — one continuous effort.
- **segment** — one monitor photo inside a session, labelled warmup / main / cooldown / extra.
- **session** — one training outing. Has one or more segments.
- **erg** — the machine. Never "rowing machine" in code.
- **novice / senior** — experience level in UK university rowing, not age. A novice is in
  their first season.
- **UI copy uses UK English**: metres, not meters. Code identifiers stay `distance_m`.
  Session and post distances always show in metres; only leaderboard totals have a
  metres/km toggle (display only — storage stays whole metres).

## Architecture

```
Rowing Pals/
  App/                  entry point, root navigation
  DesignSystem/         tokens, glass modifiers, shared components
  Features/
    Feed/               views + @Observable view models
    Capture/
    Leaderboards/
    Profile/
    Onboarding/
  Core/
    Models/             Codable structs mirroring database tables
    Services/           SupabaseClient, OCRService, StorageService
    Extensions/
```

Rules: `Features/` may import `Core/` and `DesignSystem/`. `Core/` imports neither.
No feature imports another feature.

## Swift conventions

- `async/await` throughout. No completion handlers.
- `@Observable`, not `ObservableObject`.
- All durations stored as milliseconds (`Int`). Format only at the view layer.
- All distances stored as whole metres (`Int`).
- Dates for streaks and charts use the **user's local calendar day**, never UTC.
- One type per file, named after the type.

## Verification — do this, don't skip it

After any change:

1. Build for the simulator and report the actual result.
2. For a UI change, run it, take a screenshot, and compare against the prototype or the
   relevant section of the v2 handoff. Say what differs.
3. Never report a task complete on the basis that the code looks right.

## Current focus

**Next: the coach notepad** (decision 96): phases NP1–NP4 in `docs/design/coach-notepad-build-plan.md`,
on branch `t42-coach-notepad`. NP1 and NP2 passed the phone tests and are merged into `main` (2026-11-05). NP3
(many pieces, tests, timed pieces; migration run) and NP4 (the Notebook and the rower's Feed card) are
built, waiting on the migration `2026-11-05-coach-notepad-np4.sql` and the phone tests in
`docs/testing/coach-notepad-np3.md` and `-np4.md`. Also on the branch (decision 97): editing a land session
(migration `2026-11-05-edit-workout.sql`), reps from the pieces only, and the grouped-rows land session screen
(checklist `docs/testing/land-session-edit-and-grouped.md`). That completes the notepad plan. Canvas boards `CoachNotepad…`, `CoachNotebook…` and
`RowerCoachScores…` in `docs/design/v4/`. Earlier:

**The coach version** (decisions 67–70): phases CV1–CV3 in `docs/design/coach-version-build-plan.md`, on branch
`t41-coach-version`. CV1 (the coach's own app shell), CV2 (Calendar and attendance) and CV3 (Boats and water sessions) are built, waiting on the phone tests. Earlier:

Coaching and the v4 canvas: a catch-up phase, then coaching Phases 1–3 in `docs/design/coaching-build-plan.md`. Earlier:

Implementing the v2 redesign in phases. Status and the remaining order are in
`docs/design/v2-build-plan.md`; screens and components are in
`docs/design/rowing-pals-redesign-handoff-v2.md`. The prototype is a design reference, not a spec to copy literally. Where it differs
from `docs/design/v2-decisions.md`, the decisions file wins. Anything the prototype shows
that is not covered there is a placeholder: confirm with the user before building it.
