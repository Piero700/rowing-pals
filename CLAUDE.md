# Rowing Pals

An iOS social app for rowers. Users post a training session as two simultaneous photos
(rear camera on the erg monitor, front camera on themselves), an on-device algorithm reads
the numbers off the monitor photo, and those numbers feed the feed, the profile and the
leaderboards.

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

- `docs/design/` — the current design. Start with `rowing-pals-redesign-handoff-v2.md`
  (written spec) and `rowing-pals-design-v2.html` (interactive prototype, the visual source
  of truth). **Read the relevant section before building any UI.**
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

The design is **current, not permanent**. The values below describe the v2 design
(captured 2026-09-17, full spec in `docs/design/rowing-pals-redesign-handoff-v2.md`). When
the user changes the design, update `DesignSystem/` and the docs; do not treat this section
as a reason to refuse.

Structure that should survive any redesign:

- All colours, radii, spacing and type styles are named tokens in `DesignSystem/`. Views use
  tokens only. Each accent colour has one job; a colour outside its job is a bug.
- Dark mode is the primary design. Light mode must work but is secondary.
- Typography: SF Pro. **All numerals use `.monospacedDigit()`.**

**Liquid Glass is a permanent requirement**, whatever else changes. Glass surfaces carry a
darkened outer edge and a specular top rim — a flat translucent rectangle is not glass.
The tab bar floats detached from the screen edge, shrinks on scroll down and expands on
scroll up. Content scrolls under it. Respect Increase Contrast / Reduce Transparency with
a more opaque fallback.

Current v2 palette (dark / light):

| Token | Dark | Light | Job |
|---|---|---|---|
| `Accent.brand` | `#91B8FF` | `#214FA3` | Interactive elements, active tab, links, the Log button |
| `Accent.records` | `#C6ADFF` | `#67409B` | Personal bests, avatars, the rank-hero card |
| `Accent.rank` | `#EFC37C` | `#84500B` | The #1 leaderboard row and rank-movement indicators |
| `Accent.success` | `#78D7AC` | `#176A4A` | Success confirmation and "on" toggle states |
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

Implementing the v2 redesign in phases. Status and the remaining order are in
`docs/design/v2-build-plan.md`; screens and components are in
`docs/design/rowing-pals-redesign-handoff-v2.md`. The prototype is a design reference, not a spec to copy literally. Where it differs
from `docs/design/v2-decisions.md`, the decisions file wins. Anything the prototype shows
that is not covered there is a placeholder: confirm with the user before building it.
