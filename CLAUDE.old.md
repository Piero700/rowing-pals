# Rowing Pals

An iOS social app for rowers. Users post a training session as two simultaneous photos
(rear camera on the erg monitor, front camera on themselves), an on-device algorithm reads
the numbers off the monitor photo, and those numbers feed the feed, the profile and the
leaderboards.

## Read these first

- `docs/design-brief.md` — the screen-by-screen design specification. **Read the relevant
  section before building any UI.** It is binding, not advisory.
- `docs/build-plan.md` — sequencing, environments, App Store requirements.

## Stack

- SwiftUI, targeting current iOS (Liquid Glass design system)
- Supabase — Postgres, Auth, Storage, Realtime
- Vision framework for on-device OCR (no cloud OCR, no per-image cost)
- No third-party UI libraries. If a component seems to need one, ask first.

## Hard rules — never do these

- **Never hand-edit** `RowingPals.xcodeproj/project.pbxproj`. Source files go in the
  synchronised folder and Xcode picks them up. If a file isn't being compiled, say so
  rather than editing project structure.
- **Never hardcode** a Supabase URL, anon key, or any secret. They come from the
  `.xcconfig` for the active build configuration, surfaced via Info.plist.
- **Never commit** an `.xcconfig` containing real keys. They are gitignored.
- **Never point a Debug build at the production Supabase project.**
- **Never introduce a colour** that isn't in the token set below.
- **Never use proportional figures** for any number the user reads. Every numeral in this
  app sits in a column with other numerals at some point.
- **Never force-unwrap** outside of tests.

## Design system — binding

**Redesigned 2026-09-17** — see `docs/design/rowing-pals-redesign-handoff-v2.md` for the full
source spec ([[project_redesign_v2_handoff]] tracks status). Four accent colours now, each with
exactly one job. If a colour appears outside its role, that is a bug.

| Token | Value (dark) | Value (light) | Reserved for |
|---|---|---|---|
| `Accent.brand` | `#91B8FF` | `#214FA3` | Interactive elements, active tab, links, the Log button |
| `Accent.records` | `#C6ADFF` | `#67409B` | Personal bests, avatars, the rank-hero card. Nothing else. |
| `Accent.rank` | `#EFC37C` | `#84500B` | The #1 leaderboard row and rank-movement indicators. Nothing else. |
| `Accent.success` | `#78D7AC` | `#176A4A` | Success confirmation and "on" toggle states. Nothing else. |
| `System.error` | `#FF766F` | `#C93C36` | Error/destructive text and controls — not one of the four accent roles above. |
| `Ink.primary` | `#F7F8FC` | `#111723` | Primary text |
| `Ink.secondary` | `#BBC0CE` | `#3E4C61` | Secondary text |
| `Ink.faint` | `#A3ABBA` | `#4E5C70` | Tertiary text |
| `Base` | `#101114` | `#EDF0F5` | Screen/card ground |
| `Surface.card` / `.raised` / `.line` | `#1B1C21` / `#292C34` / `#464A56` | `#FFFFFF` / `#DCE2EC` / `#949EAE` | Flat card levels and borders |

The old 3-colour cyan/gold/coral set (`Accent.signal`/`.pb`/`.live`) is retired — `.live`'s sole
reason for existing (the capture countdown) was removed outright, not just recoloured.

Dark mode is the primary design. Light mode must work but is secondary.

Liquid Glass rules: glass surfaces carry a darkened outer edge and a specular top rim —
a flat translucent rectangle is not glass. The tab bar floats detached from the screen
edge, shrinks on scroll down and expands on scroll up. Content scrolls under it.

Typography: SF Pro. **All numerals use `.monospacedDigit()`.**

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

## Architecture

```
RowingPals/
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
2. For a UI change, run it, take a screenshot, and compare against the artboard or the
   relevant section of `docs/design-brief.md`. Say what differs.
3. Never report a task complete on the basis that the code looks right.

## Current focus

The walking skeleton: sign in, capture one photo, upload it, see it appear in a list on a
second device. No styling beyond the token set, no OCR, no leaderboards. Anything outside
that scope — ask before building it.
