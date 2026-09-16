# Rowing Pals redesign — design handoff

Captured: 2026-09-16
Source: `/Users/piero/Downloads/rowing-pals-design.html`, a self-contained interactive
HTML/CSS/JS prototype (not from the Claude Design canvas project that produced
`rowing-pals-dc-handoff.md` — a different tool, a different design pass). Copied into this
repo at `docs/design/rowing-pals-design.html` so it survives independent of the user's
Downloads folder. Open it directly in a browser to explore every screen interactively.

This is the **next design iteration**, meant to eventually replace the design system
`rowing-pals-dc-handoff.md` established and everything built from it (tasks 01–15). It is
**not ready to build** — see Sequencing below.

## Sequencing — read this before touching any of it

Decided 2026-09-16, in conversation, not to be re-litigated without asking again:

1. **Finish the remaining numbered build-plan tasks first** (16 Moderation, 17 Reactions/
   comments/following, 18 Account deletion, 19 TestFlight — check `.claude/skills/rp-task/tasks.md`
   for current numbering, since the moderation/reactions ordering may already differ from
   this note). This matches the user's standing "functionality first" preference (see memory:
   `feedback_functionality_first.md`).
2. **Only then** does this redesign begin. It is a distinct phase after the 19-task plan
   completes, not one of the existing numbered tasks — there is no task number for it.

## Component hierarchy

The prototype is a JS-driven single-page shell (`#prototype`) swapping `.view` sections via a
`show(name)` function, plus a desktop-only sidebar (screen nav + theme toggle) that doesn't
apply to the iOS build. Screens present, by `data-view`:

| View | Purpose | Roughly maps to |
|---|---|---|
| `onboarding` | Find your club | `Features/Onboarding/ClubSearchView.swift` |
| `feed` | Following/Club segmented feed | `Features/Feed/FeedView.swift` |
| `rankings` | **Merged** Volume + Test-results tabs (`data-ranktab`) | `Features/Leaderboards/MetresLeaderboardView.swift` + `TestsView.swift`, combined |
| `test-detail` | One distance's leaderboard (e.g. 2k), All/Club/Following scope | `Features/Tests/TestLeaderboardView.swift` |
| `capture` | Monitor scan camera | `Features/Capture/CaptureView.swift` |
| `review` | Review session, manual-entry fallback included | `Features/Capture/ReviewSheetView.swift` |
| `profile` | Overview/PBs/Posts segmented, stats row | `Features/Profile/ProfileView.swift` |
| `pb-history` | **New** — PB progression as an interactive scrubbable SVG line chart, not a static chart | `Features/Profile/PBProgressionView.swift` (would replace the Swift Charts version) |
| `settings` | Appearance, units (metres/km, split/watts), notifications, privacy, account, app icon | **New screen** — nothing built yet (task 18 only built account deletion basics) |
| `post` | Post detail — splits, reactions, comments | `Features/Feed/PostDetailView.swift` |
| `person` / `people` | **New** — another rower's profile, followers/following lists, private-profile gating, follow requests | Nothing built yet |
| `success` | Post-confirmation screen | Nothing built yet (current app just dismisses the sheet) |

## Tokens used (the new palette — see Sequencing before adopting)

Two competing colour systems are actually layered in this file's `<style>` (later rules
override earlier ones — read the *last* definition of each variable as the real one):

- `--brand` / `--brand2`: `#91b8ff` / `#315fba` (dark) — primary interactive/action colour
  (buttons, active tab, links). Light mode: `#214fa3` for both.
- `--accent`: `#c6adff` (dark) / `#67409b` (light) — personal bests, PB chart line/points,
  "your" highlighted rows. This is the closest equivalent to the current `Accent.pb` role,
  but purple/lilac, not gold.
- `--gold`: `#efc37c` (dark) / `#84500b` (light) — rank *movement* only ("↑ 2 places"), a
  narrower role than the current app's gold (which also covers PB flags and podium ranks).
- `--good` / `--goodSoft`: `#78d7ac` / green-tinted — "New PB" badges, success checkmark.
  Not present in the current 3-token system at all.
- No dedicated "live capture" red/coral equivalent to `Accent.live` appears in this file —
  the capture screen's help overlay is neutral dark, no countdown-timer treatment shown.
- Base/ink: `--bg #09090b`, `--base #101114`, `--card #1b1c21`, `--raised #292c34`,
  `--text #f7f8fc`, `--muted #bbc0ce` (dark). Light mode: `--bg #dfe3eb` etc. — see the
  file's `:root` and `html[data-theme="light"]` blocks (lines ~32–33 of the style block) for
  every value.

**Adopting this requires reconciling 4 accent roles (brand/accent/gold/good) against the
current 3-token rule in CLAUDE.md** ("Three accent colours, each with exactly one job") —
either the rule expands to 4, or two of these collapse into one role. Not decided yet; decide
it when this phase actually starts.

## Layout and spacing

- Glass surfaces: `.nav-group`, `.bottom > .log`, `.top > .icon` share one glass treatment —
  `rgba(43,46,55,.86)` fill, `blur(24px) saturate(160%)`, inset highlight + outer shadow
  (style block line ~35). This is the file's actual Liquid Glass implementation; compare
  directly against `DesignSystem/Glass.swift`'s native `.glassEffect(_:in:)` approach before
  porting anything — this file is plain CSS blur/gradient, not a native glass API, so it's a
  *visual reference only*, not something to port as-is (native glass stays the right
  approach per task 02's own rule against hand-built blur stacks).
- Tab bar: `.bottom` is a flex row of two elements — `.nav-group` (a pill containing Feed/
  Rankings/Profile as a 3-column grid) and a separate circular `.log` button (76×76,
  offset outside the pill) for the capture/post action. This differs from the current
  native `TabView`/`Tab` five-icon row — matches the `rowing-pals-dc-handoff.md` "Known
  deviations" note that the current Post tab renders as a plain native icon rather than a
  raised circular button, because native `Tab` items can't be styled individually. **This
  file's approach (Post as a visually separate element outside the segmented group) may
  resolve that constraint** by not trying to style a `Tab` at all — worth investigating
  whether a custom bottom-bar layout (still glass, still native `.tabViewBottomAccessory`
  or similar) can achieve this without the hand-building task 04 forbade for a *segmented
  control*. Re-evaluate against current SwiftUI/iOS APIs when this phase starts, not now.
- Corner radii: `--r1 18px`, `--r2 24px`, `--r3 30px` (three-step system) vs. the current
  app's per-component radii (28/24/22/20/16-18px, listed in `rowing-pals-dc-handoff.md`).
  Different scale; reconcile when building.
- PB progression chart (`pb-history` view): a hand-drawn SVG line chart (see `drawPB()`,
  `pbCoordinates()` in the script) with a draggable scrub slider and tap-to-select points,
  not Swift Charts. `Features/Profile/PBProgressionView.swift` currently uses Swift Charts
  with `.chartYScale(domain: [max, min])` for the inverted axis (task 15) — decide whether
  the redesign keeps Swift Charts (simpler, native, accessible for free) or replicates this
  file's custom scrub interaction (richer, but hand-built).

## Assets

None — every avatar/crest in the file is text initials on a gradient circle
(`.avatar`/`.crest`), no image assets to extract.

## Interaction notes

- Feed scope is a 2-way Following/Club segmented control, not the current app's 3-way
  Following/My Club/Global.
- Rankings' "Filters" is a single header icon opening a bottom sheet (`<dialog class="sheet">`)
  with a scope `<select>` (All clubs/My club/Following) — one unified filter sheet, rather
  than the current app's inline Male/Female + All/Erg/Water chip rows plus a separate scope
  row all visible at once on `MetresLeaderboardView`.
  by profile privacy status; follow requests for private profiles. None of this exists in
  `docs/schema.sql` yet (no `is_private` column, no `follow_requests` table/status) — task
  17 (Reactions/comments/following, per current numbering) only builds plain follow/unfollow,
  not privacy/requests. Decide whether privacy + requests get added to task 17's scope or
  folded into this redesign phase instead, when the time comes.
- Settings screen is entirely new: distance unit (metres/km — conflicts with CLAUDE.md's "UI
  copy uses UK English: metres, not meters" rule as currently written, since it makes metric
  display a *user choice* rather than fixed; needs a decision, not silent adoption), pace
  display (split vs watts), notification toggles, quiet hours, profile visibility, CSV
  export, app icon picker, delete account. Task 18 (Account deletion, current numbering)
  only scoped account deletion + basic settings — this is considerably more.
- Manual session entry (`data-manual` on the capture screen, skips the camera entirely) —
  not in the current app or any numbered task. New capability, not just new styling.

## Ready to build?

**No.** Deferred until tasks 16–19 are complete and verified, per the sequencing decision
above. When that point is reached, re-read this file in full (`docs/design/rowing-pals-design.html`
— open it in a browser, it's interactive) rather than relying solely on this summary, and
resolve the open decisions flagged inline above (4-colour-role reconciliation, glass
implementation approach, Swift Charts vs custom SVG chart, privacy/follow-requests schema
work, settings scope, metric-unit toggle vs CLAUDE.md's fixed-metres rule) before writing
any code.
