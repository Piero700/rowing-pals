# Rowing Pals v3 — design handoff
Captured: 2026-09-25

Source: `/Users/piero/Downloads/Rowing Pals prototype rebuild.zip` (a Claude Design handoff),
copied verbatim into `docs/design/v3/`. **v3 supersedes the v2 visuals** (`rowing-pals-design-v2.html`)
for look, sizing and layout. Behaviour/product decisions still come from `v2-decisions.md`, which
wins wherever this bundle disagrees (see "Conflicts" at the end).

| File in `docs/design/v3/` | Use |
|---|---|
| `README.md` | Designer's own handoff notes — tokens, components, all 12 screens. Read in full. |
| `RP Screen.dc.html` | **Exact markup for every screen**, inline styles. Sections are marked `<!-- 01 ONBOARDING -->` … `<!-- 12 CLUBS -->`. Use it for any value not written below. |
| `Rowing Pals Editable.dc.html` | All 12 screens, dark + light side by side. Theme tokens defined on each phone frame. |
| `Rowing Pals.dc.html` + `rowing-pals-app.js` | Clickable behaviour prototype. |
| `Rowing Pals Artboards.dc.html` | Live instances of each screen. |
| `support.js` | Runtime for opening the `.dc.html` files (`npx serve docs/design/v3`). Not app code. |

Canvas: **393 × 852 pt** (iPhone 15/16/17 Pro). Fidelity: **high — colours, type, spacing, radii and
sizes are final.**

## Component hierarchy

App shell
- System status bar (real one; mock is 51 pt).
- **Tab screens** (Feed, Rankings, Profile): large-title header → scrolling content → floating
  bottom navigation.
- **Pushed screens** (Other profile, Find rowers, PB history, All PBs, Settings, Clubs, workout
  detail…): compact header (44 pt glass back button, 17 pt title, optional brand text action) →
  content. No bottom navigation.
- **Log** opens capture as a full-screen modal, no tab bar: Capture → Review → Success.
- **Sheets**: filters, privacy, follow requests, reactions picker, etc.

Screens (full detail in `README.md` §Screens and the matching `RP Screen.dc.html` section):
1. Onboarding — Find your club
2. Activity feed — "Your crew"
3. Rankings
4. Log workout (capture)
5. Review session
6. Profile
7. Settings
8. Other profile
9. Find rowers
10. PB history
11. All personal bests
12. Clubs — "Your crew" + Create club
Present in the behaviour prototype but not drawn: 2k leaderboard detail, workout detail with
comments, success screen, filters/privacy/follow-request sheets, manage club.

Shared components: glass segmented control (sliding thumb), bottom nav pill + Log circle, glass
icon button (44), primary / secondary / text / destructive buttons, input + search input, switch,
avatar with streak badge, dual-camera photo, metric trio, workout-link row, reaction pill,
leaderboard row, PB tile, estimate card, bar chart, consistency heatmap, line chart with scrubber.

## Tokens used

### Colours (same values as `Tokens.swift` today, plus four new ones)
| v3 token | Dark | Light | Existing Swift token |
|---|---|---|---|
| bg | `#09090b` | `#dfe3eb` | **new** — outer background |
| base | `#101114` | `#edf0f5` | `Tokens.Base.ground` |
| card | `#1b1c21` | `#ffffff` | `Surface.card` |
| raised | `#292c34` | `#dce2ec` | `Surface.raised` |
| line | `#464a56` | `#949eae` | `Surface.line` |
| cardEdge | `rgba(70,74,86,.7)` | `#a8b1bf` | **new** — card borders |
| text / muted / faint | `#f7f8fc` / `#bbc0ce` / `#a3abba` | `#111723` / `#3e4c61` / `#4e5c70` | `Ink.primary/.secondary/.faint` |
| brand | `#91b8ff` | `#214fa3` | `Accent.brand` |
| brandSoft | `rgba(145,184,255,.14)` | `rgba(33,79,163,.12)` | `Accent.brandSoft` |
| onBrand | `#09090b` | `#ffffff` | **new** — text on primary buttons |
| accent (lilac) | `#c6adff` | `#67409b` | `Accent.records` |
| accentSoft | `rgba(198,173,255,.12)` | `rgba(103,64,155,.10)` | `Accent.recordsSoft` |
| gold / goldSoft | `#efc37c` / `rgba(239,195,124,.12)` | `#84500b` / `rgba(132,80,11,.10)` | `Accent.rank` / `.rankSoft` |
| good | `#78d7ac` | `#176a4a` | `Accent.success` |
| bad | `#ff766f` | `#c93c36` | `System.error` |

Roles unchanged: blue = actions, lilac = records, amber = rank movement, green = success.

### Liquid glass (all **new** tokens)
| Token | Dark | Light |
|---|---|---|
| lg-fill | `rgba(58,62,74,.42)` | `rgba(255,255,255,.52)` |
| lg-fill-strong (selected) | `rgba(92,98,114,.55)` | `rgba(255,255,255,.92)` |
| lg-edge (1 px border) | `rgba(255,255,255,.16)` | `rgba(40,55,85,.16)` |
| lg-hi (inner top highlight) | `rgba(255,255,255,.28)` | `rgba(255,255,255,.95)` |
| lg-lo (inner bottom shade) | `rgba(0,0,0,.22)` | `rgba(30,45,75,.08)` |
| lg-shadow | `0 8 24 rgba(0,0,0,.22)` | `0 6 20 rgba(25,40,70,.12)` |

Recipe: fill lg-fill; 1 px lg-edge border; inner top 1 px lg-hi; inner bottom 1 px lg-lo; drop
shadow lg-shadow; blur 22 + saturate 180 %. Reduce Transparency → solid `raised`.
Applied to: segmented controls, bottom nav group, Log button, header icon buttons, secondary
buttons, pills/reactions, filter controls, slider track/thumb, icon choices.
Primary button: vertical gradient brand+12 % white → brand; border brand@60 % + white@40 %;
inner top `rgba(255,255,255,.45)`; glow `0 8 22 brand@30%`.

### Typography
Font family in the bundle: **Inter**, fallback SF Pro (see Conflicts). Tabular numerals everywhere.
| Role | Size / weight / tracking / line height |
|---|---|
| Large title (tab screens) | 29 / 700 / -0.04 em / 1.1 |
| Onboarding title | 33 / 700 / -0.05 em / 1.05 |
| Compact nav title | 17 / 700 / -0.01 em |
| Profile name | 23 / 700 |
| Big result | 36 / 820 / -0.055 em (29 in review card) |
| Hero number (rankings) | 32 / 700 / -1 pt |
| Body / caption | 16 / 400 / lh 1.5 |
| Name | 15 / 740 |
| Meta | 12.8 / 400 / lh 1.4, muted |
| Section title | 12 / 780, uppercase, +0.09 em, muted |
| Overline | 12 / 760, uppercase, +0.1 em |
| Metric label | 12 / 760, uppercase, +0.07 em |
| Metric value | 17 / 730 |
| Nav label | 11 / 740 |
| Segmented label | 14 / 730 |
| Reaction / pill text | 13 / 700 |

### Radii
Cards 30 · inputs, clubs, splits, PB tiles 24 · estimate cards 22 · photo 22 · front-camera inset 17
· icon choices 20 · workout link 18 · selects 15 · crest 13 · every interactive control (buttons,
pills, segmented, nav) fully rounded (999).

## Layout and spacing
- Screen side padding **15**; header padding **8 / 18 / 14** (top / sides / bottom), min height 61.
- Card padding **15**; common gaps **8 / 10 / 12**; section title margin 20 top / 9 bottom.
- Tab-screen scroll bottom inset **90** (clears the nav).
- **Bottom navigation**: floating, left/right **16**, bottom **6**, height **58**. Glass pill group
  (3 equal columns, padding 4) + separate **58 × 58** glass circle Log button, **4 pt gap**. Item =
  20 pt icon over 11 pt label, gap 2. Selected = lg-fill-strong thumb + brand colour. Log = plus
  icon 24 pt, brand, label "Log workout" for VoiceOver.
- **Segmented control**: glass pill, padding 4, no gap, equal segments, min height **44**. Selected
  thumb slides (0.32 s, cubic-bezier(.3,1.4,.5,1), slight overshoot). Unselected text muted.
- **Buttons**: primary 54 tall full width · secondary (glass) 52 · text 44 (brand) · destructive:
  bad@13 % fill, bad text, radius 24 · press = scale 0.96.
- **Inputs**: 52–54 tall, card fill, 1 px line, radius 24, padding 12/14; search icon 20 pt inset 14.
- **Switch**: 50 × 29, knob 23–25 white, on = good.
- **Avatar**: circle, 145° gradient accentSoft → raised, initials in accent weight 800. Sizes
  76 / 41 / 38 / 32. Streak badge 🔥 23 pt card-coloured circle at top-right, offset −5/−5, 15 pt.
- **Dual-camera photo**: 4:3, radius 22; front inset top-right 10/10, **27 % × 37 %**, radius 17,
  2 pt card border, shadow `0 5 14 #0005`.
- **Minimum tap target 44 pt** throughout (reaction pills 40 tall × ≥44 wide is the one exception).

### Feed post card (from `RP Screen.dc.html` §02, exact)
Card: margin-top 12, padding 15, card fill, 1 px cardEdge, radius 30.
1. Header row, gap 11: avatar 41 (+ streak) · name 15/740 · club meta 12.8 muted.
2. Dual-camera photo, margin-top 14.
3. Metric trio, 3 equal columns, gap 8, margin 12/0: label 12/760 uppercase +0.07 em muted;
   value 17/730 tabular, 3 pt above. Labels: **Distance, Time, /500m**.
4. Caption 16 / lh 1.5, margin 13 top / 9 bottom.
5. Workout-link button: full width, padding 15, raised fill, 1 px line, radius 18, min height 68,
   title 14 bold ("UT2 · Main workout"), meta 12 muted 6 pt below ("12,000m · 47:28.8 · 3
   splits"), chevron 18.
6. Reactions row, wrap, gap 8, margin-top 14: glass pills 40 tall, ≥44 wide, padding 0/12, 13/700;
   last pill "＋☺" muted.
7. Divider 1 px line, then actions row (padding-top 9, margin-top 12): comments glass pill (44 tall,
   bubble icon 20 + count) left, share glass circle 44 right.
The card has **no card-wide tap target**: only the photo, workout link, name/avatar, pills and
buttons are tappable. (This is the fix for taps landing on the wrong thing.)

### Other screens
Headline values per screen are in `README.md` §Screens (rows 72 tall on leaderboards with grid
`20 | 32 | 1fr | auto`; onboarding club rows 76 tall with 44 crest; capture shutter 76 white with 6
pt raised ring + 2 pt white outer, flip/library 48 glass; profile 4-up stats; settings icon grid
4-up; etc.). Anything finer comes from the screen's section in `RP Screen.dc.html`.

## Assets
- **Icons**: 24 pt stroke glyphs, 1.9 stroke, round caps → SF Symbols: `house`, `chart.bar`,
  `person`, `plus`, `chevron.left` / `chevron.right`, `gearshape`, `magnifyingglass`, `heart`,
  `bubble.left`, `square.and.arrow.up`, `checkmark`, `line.3.horizontal.decrease`, `paperplane`.
- **Emoji**: 🔥 streak and reaction emoji are part of the design.
- **Photos**: placeholders only; the app uses the rower's own captures.
- **App icon choices**: Lagoon `#168f82`, Midnight `#233853`, Pearl `#6c929a`, Custom.
- No image files ship in the bundle; nothing to copy into `docs/design/assets/`.
- **Missing**: PNG exports of each artboard, which `/rp-verify` compares screenshots against.

## Interaction notes
- Tab bar switches Feed / Rankings / Profile; Log opens capture modally.
- Capture → Review. Photo mode pre-fills and **requires stroke-rate confirmation**; manual mode
  starts empty.
- Review validation: distance integer > 0; time `h:mm:ss` or `mm:ss(.t)`; pace `m:ss(.t)`; rate
  **1–99** (optional "spm").
- Post → success → feed shows the new values; "Include on leaderboards" adds to weekly volume.
- Segmented controls filter content (feed scope, rank type, leaderboard scope, profile tabs).
- Reactions toggle (pressed = brand tint). Comments append to the thread.
- Follow: public → Following; private → Requested; accepting adds a follower.
- PB chart: tap/drag the line, or slider / arrows.
- Theme dark / light in Settings.
- Motion: press scale 0.96; segmented thumb slides; screen enter fade + 4 pt translate, 0.2 s
  ease-out. Honour Reduce Motion and Reduce Transparency.

## Conflicts with earlier decisions (must be settled before building)
1. **Font: Inter vs SF Pro.** CLAUDE.md says SF Pro; the bundle uses Inter with SF Pro as fallback.
   Using Inter means bundling the font file (free, OFL licence) in the app.
2. **Custom app icon from a photo.** iOS only allows alternate icons that are compiled into the
   app; an icon made from a photo picked at runtime is not possible. Lagoon / Midnight / Pearl are
   possible.
3. **Export CSV** is back in Settings; decision 4 says no CSV export. Decisions win until changed.
4. **Settings "Metres | km"** — decision 3 limits km to leaderboard totals; the label should say
   so.
5. **Feed photo**: the bundle draws one dual-camera photo per card; decisions 10–11 (2026-09-25)
   add a swipeable carousel with the most intense piece first, and decision 12 adds the PB glow.
   The carousel reuses the bundle's 4:3 photo frame.
6. **Feed metric trio vs lead piece**: the bundle shows session Distance / Time / /500m; decision
   10 puts the lead piece first. Proposed: the trio shows the session totals, the workout-link row
   names the lead piece.
