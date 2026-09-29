# Handoff: Rowing Pals — iOS app UI

## Overview
Rowing Pals is a social rowing app: log erg/indoor sessions (photo of the monitor or manual entry), share them with your crew, compare on leaderboards, and track personal bests, weekly volume and streaks. This package covers 12 screens in dark and light mode.

## About the Design Files
The files here are **design references built in HTML** — they show the intended look and behaviour; they are **not production code to copy**. Recreate them in the target codebase's existing environment (SwiftUI, React Native, Flutter, etc.) using its established patterns and libraries. If no app exists yet, SwiftUI is the natural fit (the design is an iOS study using system-style "liquid glass" controls).

## Fidelity
**High-fidelity.** Colours, type, spacing, radii and component sizes are final. Recreate pixel-accurately at a 393×852 pt iPhone canvas, using native equivalents where they exist (e.g. `Material` / glass effects for the glass layer, `Picker(.segmented)` restyled, `TabView`-style bottom bar).

## Files
| File | What it is |
|---|---|
| `Rowing Pals Editable.dc.html` | **Primary reference.** Canvas of all 12 screens, dark + light side by side. Theme tokens are defined on each phone frame. |
| `RP Screen.dc.html` | Markup for every screen (one `screen` prop switches between them). All styles are inline; all sample data is in the logic class at the bottom. |
| `Rowing Pals.dc.html` + `rowing-pals-app.js` | **Behaviour reference.** The original clickable prototype (navigation, segmented sliding, toggles, filters, follow/unfollow, PB chart scrubbing, custom icon upload, post flow). Open in a browser. |
| `Rowing Pals Artboards.dc.html` | Live prototype instances of each screen (dark/light). |
| `support.js` | Runtime required to open the `.dc.html` files in a browser. Not part of the app. |

Open any `.dc.html` directly in a browser (serve the folder, e.g. `npx serve`).

---

## Design Tokens

### Colours
| Token | Dark | Light | Use |
|---|---|---|---|
| bg | `#09090b` | `#dfe3eb` | Outer background |
| base | `#101114` | `#edf0f5` | Screen background |
| card | `#1b1c21` | `#ffffff` | Cards, inputs |
| raised | `#292c34` | `#dce2ec` | Raised fills, selects, placeholders |
| line | `#464a56` | `#949eae` | Dividers, input borders |
| cardEdge | `rgba(70,74,86,.7)` | `#a8b1bf` | Card borders |
| text | `#f7f8fc` | `#111723` | Primary text |
| muted | `#bbc0ce` | `#3e4c61` | Secondary text |
| faint | `#a3abba` | `#4e5c70` | Tertiary text |
| brand | `#91b8ff` | `#214fa3` | Actions, links, selected nav |
| brandSoft | `rgba(145,184,255,.14)` | `rgba(33,79,163,.12)` | Selected rows, "you" highlight |
| onBrand | `#09090b` | `#ffffff` | Text on primary buttons |
| accent (lilac) | `#c6adff` | `#67409b` | Records/PBs, avatars, today marker |
| accentSoft | `rgba(198,173,255,.12)` | `rgba(103,64,155,.10)` | Estimate cards, avatar gradient |
| gold | `#efc37c` | `#84500b` | Leaderboard #1, rank movement |
| goldSoft | `rgba(239,195,124,.12)` | `rgba(132,80,11,.10)` | Winner row |
| good | `#78d7ac` | `#176a4a` | Switch on, success |
| bad | `#ff766f` | `#c93c36` | Destructive |

Palette roles: **blue = actions, lilac = records, amber = rank movement, green = success.**

### Liquid glass layer
Applied to: segmented controls, bottom nav group, Log button, header icon buttons, secondary buttons, pills/reactions, filter controls, slider track/thumb, icon choices.

| Token | Dark | Light |
|---|---|---|
| lg-fill | `rgba(58,62,74,.42)` | `rgba(255,255,255,.52)` |
| lg-fill-strong (selected thumb) | `rgba(92,98,114,.55)` | `rgba(255,255,255,.92)` |
| lg-edge (1px border) | `rgba(255,255,255,.16)` | `rgba(40,55,85,.16)` |
| lg-hi (inner top highlight) | `rgba(255,255,255,.28)` | `rgba(255,255,255,.95)` |
| lg-lo (inner bottom shade) | `rgba(0,0,0,.22)` | `rgba(30,45,75,.08)` |
| lg-shadow | `0 8px 24px rgba(0,0,0,.22)` | `0 6px 20px rgba(25,40,70,.12)` |

Recipe: `background: lg-fill; border: 1px lg-edge; box-shadow: inset 0 1px 0 lg-hi, inset 0 -1px 0 lg-lo, lg-shadow; backdrop-filter: blur(22px) saturate(180%)`.
Primary button: vertical gradient from brand+12% white → brand, 1px border brand/60% + white/40%, inner top highlight `rgba(255,255,255,.45)`, glow `0 8px 22px brand@30%`.
Respect *Reduce Transparency*: fall back to solid `raised`.

### Typography
Font: Inter (fallback: SF Pro Text / system). Tabular numerals on all figures.
| Role | Size / weight / tracking |
|---|---|
| Large title (tab screens) | 29 / 700 / -0.04em, lh 1.1 |
| Onboarding title | 33 / 700 / -0.05em, lh 1.05 |
| Compact nav title (pushed screens) | 17 / 700 / -0.01em |
| Profile name | 23 / 700 |
| Big result | 36 / 820 / -0.055em (29 in review card) |
| Hero number (rankings) | 32 / 700 / -1px |
| Body / caption | 16 / 400, lh 1.5 |
| Name | 15 / 740 |
| Meta | 12.8 / 400, lh 1.4, muted |
| Section title | 12 / 780, uppercase, +0.09em, muted |
| Overline | 12 / 760, uppercase, +0.1em |
| Metric label | 12 / 760, uppercase, +0.07em |
| Metric value | 17 / 730 |
| Nav label | 11 / 740 |

### Radii
Cards 30 · inputs/clubs/splits/PB tiles 24 · estimate cards 22 · photo 22 · icon choices 20 · workout link 18 · selects 15 · crest 13 · everything interactive (buttons, pills, segmented, nav) fully rounded (999).

### Spacing
Screen side padding 15 (header 18). Card padding 15. Common gaps 8 / 10 / 12. Section title margin 20 top / 9 bottom. Scroll bottom inset 90 on tab screens (clears nav).

---

## Global components

- **Status bar** 51pt tall; Dynamic Island mock 106×27. Use the real system status bar.
- **Header (tab screens)**: min-height 61, padding 8/18/14, large title left, 44pt glass circle icon buttons right.
- **Header (pushed screens)**: 44pt glass back button, 17pt title, optional text action (brand).
- **Bottom navigation** (Feed, Rankings, Profile only): absolute, left/right 16, bottom 6, **height 58**. A glass pill group (3 equal columns, padding 4) + a separate **58×58 glass circle Log button, 4pt gap**. Nav items: 20pt icon over 11pt label, gap 2. Selected item = lg-fill-strong thumb + brand colour. Log button is icon-only (plus, 24pt, brand), accessibility label "Log workout".
- **Segmented control**: glass pill, padding 4, **no gap between segments**, segments flex equally, min-height 44, 14/730. Selected = lg-fill-strong thumb with 1px edge + inner highlight; **the thumb slides** between segments (`left` transition .32s `cubic-bezier(.3,1.4,.5,1)`, slight overshoot). Unselected text muted.
- **Buttons**: Primary 54 tall, full width. Secondary (glass) 52 tall. Text button 44 tall, brand. Destructive: bad @13% fill, bad text, radius 24. Press: scale .96.
- **Inputs**: 52–54 tall, card fill, 1px line, radius 24, padding 12/14. Search has 20pt icon inset 14.
- **Switch**: 50×29, knob 23–25 white; on = good.
- **Avatar**: circle, gradient 145° accentSoft→raised, initials in accent 800. Sizes 76 / 41 / 38 / 32. Streak badge 🔥 in a card-coloured circle, top-right.
- **Photo placeholders**: rear-camera main (4:3, radius 22) with front-camera inset top-right (27%×37%, radius 17, 2px card border).

---

## Screens

1. **Onboarding — Find your club.** Overline "Set up your crew" (brand), title, intro. Club search input. Club list (76 tall rows: crest 44, name, "48 members · Norwich · Open membership", check circle). Selected row: brand border + brandSoft fill. "I'm not in a club" text button. Sticky primary "Continue with {club}" over a base-colour fade.
2. **Activity feed — "Your crew".** Search icon. Segmented Following / Club; meta "You and people you follow". Post card: avatar+streak, name, club; dual-camera photo; 3 metrics (Distance, Time, /500m); caption; workout link row (raised, "UT2 · Main workout" / "12,000m · 47:28.8 · 3 splits", chevron); emoji reaction pills + add-reaction pill; divider; comments pill + share pill (right). Bottom nav.
3. **Rankings.** Segmented Volume / Test results. Hero card (lilac→card gradient): "Weekly volume · You", 116,250 m, "5,651m to move into #2", overall leader line. Gender + Level selects (2-col). Segmented All / My club / Following. "This week · 6 rowers match". Leaderboard card: rows 72 tall, grid `20 | 32 | 1fr | auto`; #1 shows ♛ in gold with goldSoft fill + 3pt gold inset bar; current user row brandSoft.
4. **Log workout.** Back, title, "Help". Dual-camera capture area (rear main, front inset), note "Front + rear · No time limit". Glass secondary "Enter session manually". Controls row: flip camera (48 glass), shutter (76 white, 6pt raised ring + 2pt white outer), library (48 glass).
5. **Review session.** Total card; 2-col fields Distance / Time / Average /500m / Stroke rate (stroke rate has inline "Confirm" glass pill → turns "Checked" in good colour; posting is blocked until confirmed for photo logs). Main-workout label select; split rows (badge, distance·time, pace). Caption textarea; photos; session type select; "Include on leaderboards" switch. Sticky primary "Post session" → success screen.
6. **Profile.** Gear icon → Settings. Avatar 76 + streak, name, "UEA Boat Club · Senior". Followers / Following counts (tap → lists). "Find rowers". 4-up stats (weekly volume, sessions, PBs, streak days). Segmented Overview / PBs / Posts. Top PBs (2-up tiles, lilac values → PB history). Two "Estimated today" cards (illustrative). Weekly volume bar chart (12 weeks, current week lilac, others brand @65%, axis 0/62.5k/125k). Consistency heatmap (7 rows × 12 weeks; logged = brand, today = accent outline, future 22% opacity; legend). Recent activity link; "Your club" secondary.
7. **Settings.** App icon grid (4 up: Lagoon `#168f82`, Midnight `#233853`, Pearl `#6c929a`, Custom — dashed tile, opens photo picker, image centre-cropped square). No captions under icons. Groups: Appearance (Dark / Light), Units (Metres|km, Split|Watts compact segmented), Notifications (3 switches + Quiet hours), Privacy (Profile visibility → Public/Private sheet; Who can comment), Account (Edit profile, Export CSV, Log out). Delete account (destructive). Version footer.
8. **Other profile.** Back, "Rower profile". Avatar, name, club, "Public profile". Follow button states: Follow / Following / Requested (private) / Follow back. Counts; 4-up volume stats; PB tiles; overall rankings 3-up. Private + not following → locked card "This profile is private".
9. **Find rowers.** Search field; list rows (avatar 38, name + club, glass Follow button).
10. **PB history.** "PB history · 2K". Estimate card; current PB summary with "x faster" chip; period segmented (3 months / 6 months / All time); line chart (brand line 3pt, soft fill, dashed guide, selected dot accent r6); selected result panel; scrub row (prev / slider / next); history list (selected row brandSoft + brand text).
11. **All personal bests.** 2-up grid of every test (500m, 1k, 2k, 5k, 10k, 30 min, 60 min) → PB history.
12. **Clubs — "Your crew".** Current club name, explainer, primary "Find a club to join", secondary "Create a club", text "Continue without a club". Create-club form: name, description, location, who can join (open / request approval / invite only), focus.

Not drawn as artboards but present in the prototype: 2k leaderboard detail, workout detail with comments, session-posted success, filters / privacy / follow-request sheets, manage club.

## Interactions & Behaviour
- Tab bar switches Feed / Rankings / Profile; Log opens capture (modal, no tab bar).
- Capture → Review (photo mode pre-fills values and requires stroke-rate confirmation; manual mode starts empty).
- Review validation: distance integer > 0; time `h:mm:ss` or `mm:ss(.t)`; pace `m:ss(.t)`; rate 1–99 (optional "spm").
- Post → success → feed shows the new values; if "Include on leaderboards" is on, add to weekly volume.
- Segmented controls filter content (feed scope, rank type, leaderboard scope, profile tabs).
- Reactions toggle (pressed = brand tint). Comments append to the thread.
- Follow logic: public → following; private → requested; accepting a request adds a follower.
- PB chart: tap/drag the line or use slider/arrows to select a result.
- Theme: dark / light, user-selectable in Settings.
- Press feedback scale .96; segmented thumb slides; screen enter: fade/translate 4pt, .2s ease-out. Honour Reduce Motion.

## State
`currentUser`, `people` (name, initials, club, volume, rank, pb, private, streak, gender, level), `following`, `followers`, `requests`, `posts` (distance, duration, pace, rate, label, caption, splits, reactions, comments, photos), `testRecords` / PB history per test, `club` (membership, role, requests), settings (theme, units, pace display, notifications, privacy, app icon). All data in the designs is sample data.

## Assets
Icons are simple 24pt stroke glyphs (1.9 stroke, round caps) — map to SF Symbols: house, chart.bar, person, plus, chevron.left/right, gearshape, magnifyingglass, heart, bubble.left, square.and.arrow.up, checkmark, line.3.horizontal.decrease, paperplane. Emoji (🔥 streak, reaction emoji) are part of the design. Photos are placeholders — use the user's captured images.
