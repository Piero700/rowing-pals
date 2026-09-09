# Claude Design canvas — design handoff

Captured: 2026-09-09
Source: Claude Design project `iOS App Design System`
(projectId `74fb3825-c106-482d-8196-cd8a8aaafd7d`), file `Rowing Pals.dc.html`
Imported via the DesignSync MCP tool (pull import, not a "Send to Claude Code" push).

This captures the canvas so it survives past the importing session. It backs the SwiftUI
implementation on branch `design-import-core-screens` (9 screen files + 4 shared
DesignSystem components), built as static UI with mock data — no Supabase/camera/OCR wiring.

## Component hierarchy

The canvas lays out 9 iPhone artboards (393×852) side by side, each an absolute-positioned
mockup, plus light-mode variants and two "extra state" screens gated behind
`showLightMode`/`showExtraStates` props. Screens and their SwiftUI counterparts:

| # | Canvas section | SwiftUI file |
|---|---|---|
| 01 | Onboarding · Find your club | `Features/Onboarding/ClubSearchView.swift` |
| 02 | Feed · tab bar expanded | `Features/Feed/FeedView.swift` + `SessionCardView.swift` |
| 03 | Capture · dual camera, live only | `Features/Capture/CaptureView.swift` |
| 04 | Review sheet · check your numbers | `Features/Capture/ReviewSheetView.swift` |
| 05 | Meters · tab bar shrunk on scroll | `Features/Metres/MetresView.swift` |
| 06A | Tests · distance picker | `Features/Tests/TestsView.swift` |
| 06B | 2k board · Male · All | `Features/Tests/TestBoardView.swift` |
| 07 | Profile · PB board leads | `Features/Profile/ProfileView.swift` |
| 08 | Post detail · test result + thread | `Features/Feed/PostDetailView.swift` |

Shared components extracted (not in the canvas as discrete pieces, but repeated inline
patterns across screens, factored out during implementation):

- `DesignSystem/PlaceholderArt.swift` — `PhotoPlaceholder`, `AvatarPlaceholder`. Stands in for
  every `repeating-linear-gradient(135deg, ...)` diagonal-stripe fill in the canvas (monitor
  photos, selfies, crests, avatars, post thumbnails). Implemented as a flat
  `Tokens.Ink.primary.opacity(0.08)` fill rather than true diagonal stripes — a deliberate
  simplification, not a fidelity gap that matters once real photos land.
- `DesignSystem/PillSegmentedControl.swift` — the capsule segmented control appearing as
  Novice/Senior, Following/My Club/Global, Week/Month/Year, Male/Female, All/Novice/Senior.
- `DesignSystem/FilterChip.swift` — single pill chips: All/Erg/Water, segment tags
  (Warmup/Main/Cooldown/Extra), distance tags.
- `DesignSystem/StatColumn.swift` — label-over-value stat (feed data strips, profile header
  stats, review-sheet totals).

## Tokens used

All from the existing `DesignSystem/Tokens.swift` (task 01) and `GlassSurface.swift`
(task 02) — no new tokens introduced:

- `Tokens.Accent.signal` (`#3AD7E5`) — active tab, links, Post button, capture-flow Post CTA,
  low-confidence field underline in the review sheet.
- `Tokens.Accent.pb` (`#F5C542`) — PB badge, PB card border/tint, PB headline numeral, gold
  rank numerals for podium/leaderboard ranks 1–3.
- `Tokens.Accent.live` (`#FF6B5A`) — capture-window countdown banner and progress bar only.
- `Tokens.Base.ground` / `Tokens.Ink.primary` / `Tokens.Ink.secondary` — every other surface
  and text colour.
- `.glassSurface(cornerRadius:)` — every glass card/strip/pill (data strips, review-sheet
  cards, search field, pinned Metres row, composer bar).

## Layout and spacing

- Glass card corner radii follow the canvas fairly closely: 28px session cards, 24px data
  strips/PB banners, 22px review-sheet cards, 20px list rows, 16–18px small pills/fields.
- Distance tiles and PB tiles: 3-column grid, `GridItem(.flexible())`, 9–10pt spacing,
  `minHeight: 96–106` (canvas uses `aspect-ratio:1`; switched to a fixed min-height because a
  true 1:1 aspect ratio inside a `LazyVGrid` cell was shrinking below its content's needed
  height and truncating text — see Known deviations).
- Metres podium rows: gold numeral + avatar + name/club + two-tone erg/water bar + trailing
  total, `13px` padding, `22px` corner radius; non-podium rows drop to `12px`/`20px`.
- The Metres "pinned own row" is implemented as an `.overlay(alignment: .bottom)` on
  `MetresView`'s `ScrollView` (padding 20pt above the tab bar), **not** `TabView`'s
  `.tabViewBottomAccessory` — that API's glass background rendered even with empty content on
  every other tab, so it was reverted to a manual, tab-scoped overlay. See Known deviations.

## Assets

None — every "photo" in the canvas (monitor photos, selfies, crests, avatars, post
thumbnails) is a placeholder pending real capture/storage (tasks 07/08) and Supabase Storage
(task 05). `PhotoPlaceholder`/`AvatarPlaceholder` stand in throughout.

## Interaction notes

- Feed card tap → `PostDetailView` via `.fullScreenCover`.
- Tests: only the **2k** distance tile is interactive → `TestBoardView` via
  `.fullScreenCover`. Other 8 tiles are static for this pass (no per-distance mock boards
  built yet).
- Post tab → `PostSheetView` (a `.sheet`) → `NavigationStack { CaptureView() }`. Shutter tap →
  pushes `ReviewSheetView` inside that same sheet's `NavigationStack` (safe: nested navigation
  inside a sheet doesn't touch the tab's own scroll-to-minimize behaviour).
- **Critical constraint discovered during implementation**: a tab's root `ScrollView` must be
  the *direct* child of that tab's content view. Wrapping it in a `NavigationStack` — even
  transparently — stops `.tabBarMinimizeBehavior(.onScrollDown)` from firing (found during
  task 04, reconfirmed here). All five tab roots (Feed, Metres, Tests, Profile, and the Post
  sheet's own root) keep this shape; every drill-in (2k board, post detail, review sheet) uses
  `.sheet`/`.fullScreenCover`/a nested `NavigationStack` instead of `NavigationLink`.

## Known deviations from the canvas

- **Light-mode variants (L1 Feed, L2 Meters) and extra states (S1 empty board, S2 post
  success) were captured but not built.** Light mode works via `Tokens`' existing dynamic
  colour resolution rather than a bespoke layout; the empty/success states are out of scope
  for this pass (user decision — see conversation, not re-litigated here).
- **Onboarding (`ClubSearchView`) is not wired into app launch.** There's no sign-in gate yet
  (task 05/06); it only has its own `#Preview`.
- **The Post tab renders as a plain native `Tab()` icon+label**, not the canvas's raised
  circular cyan button (58×58, `margin-top:-30px`, no label). Native `TabView`/`Tab` items
  can't be styled that individually without hand-building the bar, which task 04 explicitly
  forbids. User decision: ship native-only for now, revisit custom Post-button styling later
  once the rest of the flow works end-to-end.
- Distance/PB tiles use `minHeight` instead of `aspect-ratio:1` (see Layout above).
- `FilterChip` renders every label at one fixed 10.5pt size with `minimumScaleFactor(0.75)` as
  a safety net, rather than the canvas's uniform 12–13.5px — needed so short tags (MAIN) and
  long ones (COOLDOWN) read at the same visual size inside equal-width columns; the canvas
  doesn't hit this constraint since it's static HTML, not a fixed-width SwiftUI grid.

## Ready to build?

Yes — this is a completed ad hoc UI pass (not a numbered `rp-task`), built and verified in the
simulator across all 9 screens, dark and light. It sits **ahead of** the numbered tasks that
will wire it to real data: task 05 (Supabase/models/auth) replaces the mock arrays throughout;
task 06 wires `ClubSearchView`; 07/08 wire `CaptureView`; 09/10 wire OCR + `ReviewSheetView`;
12 wires `FeedView`/`SessionCardView`; 13/14 wire `MetresView`/`TestsView`/`TestBoardView`; 15
adds the Profile charts `ProfileView` doesn't yet have; 16 wires `PostDetailView`'s reactions
and comments to Realtime.
