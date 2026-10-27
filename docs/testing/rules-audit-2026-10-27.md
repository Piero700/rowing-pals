# Rules audit — 27 October 2026

An overnight check of the app's code (the `Rowing Pals/` folder: not the tests, the website or
the marketing files) against the "Hard rules" and design rules in `CLAUDE.md`. Clear-cut
breaks were fixed. Anything that needs your judgement is listed under **Needs your decision**.

- **Branch:** `claude/rules-audit-e56065`, three commits on top of `bcec0a0` (the Side picker
  spacing commit). Nothing has been merged or pushed.
- **Nothing should look different.** Every fix uses the same value the screen already had, or
  adds tabular figures to text that was missing them.

## Results at a glance

| Rule | Result |
|---|---|
| No force-unwraps (`!`, `try!`, `as!`) | **Clean.** None found in the app code. |
| Swipe back from the left edge on every screen | **Clean.** Nothing turns it off. Every full-screen area closes with the edge swipe. The only exceptions are the camera and photo pickers, which are Apple's own screens. |
| Every workout time typed with `DurationTextField` | **Clean.** Session time, split, Add test, erg events, Your bests and the coach's piece editor all use it. The other number fields are distances, rates, watts and weights. |
| No on-water logging on the rower side (decision 54) | **Clean.** Every rower-side "water" reference is the coach-planned water sessions from CV3 (the Feed's boat card, Calendar, the read-only session page, the Settings filter). `SessionType` is erg only and the Water ranking filter is gone. |
| Tabular figures on every number | **Fixed 21 places** (below). |
| Vocabulary (split, rate, erg, metres) | **6 code comments fixed.** Some on-screen wording needs your decision (below). |
| No hardcoded colours, fonts, spacing or radii | **139 replaced with existing tokens.** Many more have no token that fits, so they need your decision (below). |

## What was fixed

### 1. Tabular figures (commit `f6f6efb`)

CLAUDE.md: *"Never use proportional figures for any number the user reads."* Each of these
now has `.tabularNumerals()`:

| File | Line | What it shows |
|---|---|---|
| `Features/Profile/PBHistoryView.swift` | 136 | Date under "Current personal best" |
| `Features/Profile/PBHistoryView.swift` | 292 | Dates on the chart's bottom edge ("Oct 26") |
| `Features/Profile/PBHistoryView.swift` | 334 | Date in the selected-result panel |
| `Features/Profile/PBHistoryView.swift` | 442 | Dates in the history list |
| `Features/Profile/WeeklyVolumeChart.swift` | 54 | "Week of 14 Sept" |
| `Features/Profile/WeeklyVolumeChart.swift` | 132 | Dates under the weekly bars |
| `Features/Profile/PBTileView.swift` | 22 | "2K", "5K" on PB tiles |
| `Features/Calendar/CalendarAddSheet.swift` | 24 | "Add to Tue 28 Oct" |
| `Features/Rankings/TestLeaderboardView.swift` | 115 | "Post a 2k main piece to be the first." |
| `Features/Rankings/TestLeaderboardView.swift` | 164 | "Club · 12 Oct" on each board row |
| `Features/Rankings/TestsView.swift` | 136 | "2k · Best" |
| `Features/Rankings/ErgEventDetailView.swift` | 88, 91, 116 | The event's piece ("Row your 2,000m…") |
| `Features/Feed/PostDetailView.swift` | 343 | "2000m test" over a PB |
| `Features/Feed/FeedCardView.swift` | 246 | The workout label ("2k test · Main workout") |
| `Features/Capture/ReviewSheetView.swift` | 185, 608, 611 | The test label on Review, and the "This looks like a 2k test" banner |
| `Features/Coaching/CoachRowerView.swift` | 237 | A test's name on a rower's page |
| `Features/Coaching/NewWorkoutView.swift` | 266 | The chosen test on New workout |

### 2. "Split", not "pace", in code comments (commit `935151d`)

These comments only. They called the time per 500 m a "pace":
`Core/Models/ErgEventResult.swift:20`, `Features/Capture/DraftSegment.swift:108`,
`Features/Capture/ReviewSheetViewModel.swift:99`, `Features/Capture/ReviewSheetView.swift:178`,
`Features/Capture/SegmentRowView.swift:66`, `Features/Feed/FeedCardView.swift:207`.

### 3. Spacing and corner radius from tokens (commit `6ca2dec`)

CLAUDE.md: *"Never hardcode a colour, font size or spacing value in a view."*

- **137 spacings and paddings** of exactly 8, 10 or 12 points, in 60-odd view files, now use
  `Tokens.Spacing.tight` (8), `.gap` (10) and `.loose` (12). These general grid tokens were
  already used for the same job elsewhere. The values are the same, so nothing moves.
- **The 24-point glass radius** now uses `Tokens.Radius.input`, the radius `glassSurface()`
  already uses by default: `DesignSystem/Glass.swift:15` (the default for
  `interactiveGlassSurface`) and `Features/Feed/PostDetailView.swift:365–367` (the PB banner).

## Needs your decision

### A. Design values with no token yet

The rule says every visual value comes from a token. I didn't invent new ones, because that's
a design decision. What's left:

| Kind | How many | Where they cluster |
|---|---|---|
| Spacing/padding with no matching token (mostly 4, 2, 6, 14, 16, 20, 1, 40, 30) | ~620 | Throughout. Most are in ProfileView, PostDetailView, PBHistoryView, ClubSearchView, ReviewSheetView, CrewBoatView, the Calendar screens and ClubHubView |
| Fixed sizes in `.frame(width:/height:)` | ~109 | Same screens |
| Avatar sizes (`diameter: 32 / 38 / 40 / 41 / 42 / 28 / 76`) | 13 | Rankings rows, Feed card, post page, People, Clubs, Follow requests, Profile |
| Font sizes written as numbers | 29 | List below |
| Corner radii written as numbers | ~38 | Mostly PostDetailView, ReviewSheetView, TestLeaderboardView, ConsistencyCalendarView, FeedCardView |
| White/black over photos (page dots, close buttons, photo labels) | 12 | FeedCardView 195/201, PostDetailView 207–212, ReviewSheetView 463/465, CaptureView 333/338, ProfileView 775, Buttons.swift 57, GlassSurface.swift 30 |
| Letter-spacing (`tracking`) written as numbers | 2 | FilterChip.swift 19, PlaceholderArt.swift 21 |

**Font sizes with no matching type style.** None of these match an existing `Typography` style
in both size and weight, so swapping one in would visibly change the text:

- `DesignSystem/FilterChip.swift:18` (10.5) and `DesignSystem/FollowButton.swift:71` (11.5 / 13.5 bold)
- `Features/Rankings/MetresLeaderboardView.swift:199, 210, 221, 317` (rank 17 bold; club line 10)
- `Features/Rankings/TestLeaderboardView.swift:129` (rank 20 semibold), `:171` (time 18 semibold)
- `Features/Rankings/TestsView.swift:208` (tile 22 semibold)
- `Features/Profile/ProfileView.swift:430, 436, 773`; `WeeklyVolumeChart.swift:44, 58, 81, 131`;
  `ConsistencyCalendarView.swift:31, 49, 101` (10–22 pt chart and stat labels)
- `Features/Feed/PostDetailView.swift:399` (22 semibold), `FeedView.swift:297` (20 semibold),
  `FeedCardView.swift:319` (emoji 26)
- `Features/People/FollowRequestsView.swift:58` (15.5), `Onboarding/ClubSearchView.swift:376` (crest 12 bold),
  `Capture/InsetCornerPickerView.swift:69` (14)
- `DesignSystem/PlaceholderArt.swift:20, 70, 96` (placeholder art, sized from the avatar)

**My recommendation:** most of these are on the older screens the v3/v4 redesign hasn't redrawn
yet (the post page, the Rankings boards, parts of Profile). Tokenise each screen when it's next
redesigned, rather than add dozens of one-off tokens now. If you'd rather have tokens now, say
which screens and I'll add named tokens with today's values, so nothing moves.

### B. "Pace" in what users read

CLAUDE.md: *"split … Never 'pace'"*, in code and UI. I left these alone because the v4 canvas
itself uses "2k pace" in sample copy, and some of these are standard rowing terms:

| Where | Wording | Suggestion |
|---|---|---|
| Settings → Units | "Pace shown as" (Split / Watts) | Needs a word that covers both, such as "Show splits as" or "Effort shown as" |
| Prediction details (`PredictionDetailView.swift:105, 139, 186`) | "typical pace", "That 2k pace", "Your 2k pace" | Could become "split" |
| Coach flag (`CoachFlag.swift:48`) | "rowed at about UT1 pace" | Could stay: it means the zone's intensity |
| Training zone (`TrainingZone.swift:28`) | "Race pace" | A standard zone name, so I'd keep it |
| Coach screens | "Pace Engine" | A product name, so I'd keep it |

Also in code: `PaceDisplay`, `paceDisplay` and `formattedPace(display:)` choose between split
and watts. The comment in `PaceDisplay.swift` says the "never pace" rule covers the stored
split, not this display choice. **Don't rename `PaceDisplay.storageKey`
("paceDisplayPreference")**: that would reset everyone's saved Split/Watts choice.

### C. "spm" on screen

`Features/Capture/SegmentRowView.swift:387`: the stroke-rate box shows "spm" as its grey
placeholder. The rule bans "spm" in identifiers, and this is on-screen text, so it's allowed.
Mentioned in case you'd prefer "rate".

### D. "meter" in the monitor reader

`Core/Services/MonitorParser.swift` looks for the word "meter" because the Concept2 monitor
prints it in US spelling. That's correct, so leave it.

## Verification

- **Build:** iPhone 17 Pro simulator (iOS 26.5), Debug: **succeeded, no errors.** The
  26 warnings are all from before this audit (iOS 26's `Text +` deprecation and Swift 6
  main-actor notes). None are in lines I changed.
- **Unit tests (`Rowing PalsTests`):** **215 passed, 0 failed.** That includes the snapshot
  tests for the Feed, boats, coaching cards, Wrapped pages and share card.
- **Screenshots:** I ran the app signed in on the simulator and checked the Feed, Profile and
  Rankings → Volume. Layout, spacing, the glass controls and the tab bar look the same as
  before. The numbers stay in line ("2,000m", "13:20.0", "3:20.0").
- **Not covered:** UI tests (`Rowing PalsUITests`) weren't run. I didn't open the PB history,
  test boards, erg event or Calendar Add screens in the simulator. Those changes only add
  tabular figures, and the build checks them.

To build this branch in its own folder I copied your `Debug.xcconfig` (the Debug keys) into
the worktree. Git ignores it, so it isn't in any commit.

## How to review and take these changes

1. Open **Terminal**.
2. Go to your project folder:
   `cd "/Users/piero/Documents/Rowing app/Rowing Pals"`
3. See the three commits: `git log --oneline bcec0a0..claude/rules-audit-e56065`
4. See every changed line: `git diff bcec0a0 claude/rules-audit-e56065`
   (press **Space** to page down, **q** to quit).
5. If you're happy, ask Claude to merge `claude/rules-audit-e56065` into your working branch.
   Your main checkout has uncommitted website changes in `uea-website/`, so let Claude handle
   them first rather than merging by hand.
6. For section A or B, reply with what you'd like (for example, "add tokens for the Rankings
   rows" or "change 'Your 2k pace' to 'Your 2k split'") and it can be done in a follow-up.
