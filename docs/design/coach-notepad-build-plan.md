# Coach notepad — build plan

Planned 2026-11-05. Design: decision 96 in `v2-decisions.md` and the canvas boards in
`docs/design/v4/` (`CoachNotepadWorkouts`, `CoachNotepad`, `CoachNotepadScan`, `CoachNotepadPieces`,
`CoachNotepadTest`, `CoachNotebook`, `CoachNotebookRower`, `RowerCoachScores`, `RowerCoachScoresPosted`).
Branch: `t42-coach-notepad`, from `main`, which already has the coach version (CV1 to CV3) the
notepad hangs off. Each phase is tested on the user's
phone before the next starts.

**Rules that apply everywhere:**
- **Coach-only.** Nothing written or scanned on a notepad is ever read by volume, pieces, PBs,
  predictions, streaks, Wrapped, challenges or any leaderboard (test boards included). That is
  enforced by keeping notepad data in its own tables, which none of those queries touch.
- **Tokens only.** Every number uses `.monospacedDigit()`.
- **Navigation.** Every screen is pushed through an `AppRoute` in `RouteHost`, so the swipe back
  from the left edge comes for free (decision 61).
- **Typing times.** Every time is typed with `DurationTextField` with `allowsTenths`
  (decisions 53, 56).

## Phase NP1 — the notepad page, typed scores (boards `CoachNotepadWorkouts`, `CoachNotepad`) — built, waiting on the phone tests

Written 2026-11-05 in a cloud session without Xcode, then **built and run in the simulator the same day**
against the Dev database (where the migration had already been run). It compiled first time and all 24
`NotepadRulesTests` pass. Checked in the simulator: typing a split, Next, Sat out, Clear, erg order,
text and table blocks, and everything coming back after leaving the page and after relaunching. Fixed
on the way, to match the boards:
- the Scores table: erg numbers now line up under `#`, names take the spare width and the boxes sit
  against the card's right edge (they had stopped two-thirds across);
- tables: columns share the card's width equally (they were fixed at 104 pt, with a gap on the right),
  and the column lines no longer cut through the headings;
- **Open notepad** sits inside today's card, under the bar, as on `CoachNotepadWorkouts`.

Changed after the first phone test (user, 2026-11-05):
- **Reps from the title.** A workout set with only a title and no pieces ("4 x 500m") gets one column
  per rep the title names (`NotepadRules.pieces(fromTitle:)`: "4 x 500m", "3 x 2,000m", "2 x 6k",
  "8 x 2:00", "4 x 10'", "2 x 2k + 4 x 500m"). Pieces set in New workout always win over the title.
  The scan screen counts the same reps. A title with no "count ×" (a 2k, "work out buddy") stays one column.
- **No dead space in the Scores table.** The names column is only as wide as the longest name (cut short
  with "…" when the reps need the room), the camera sits right after it, and the rep boxes share the
  rest of the card equally. With more reps than fit, boxes keep a 56 pt minimum and scroll sideways.

Still differs from the boards, on purpose: the erg-order button replaces Done top right (below), and
the system decimal pad with `DurationTextField` replaces the board's own keypad, so the tenth is typed
after "." as everywhere else in the app. Not done in NP1: the board's "Scores in 4 of 10" on today's
card (the card still says "Completed", counting posts only).

The migration was run against a local Postgres with a copy of the club, profile and workout tables.
That run checked:
- coaches in the club can read and edit;
- rowers and other clubs' coaches can't;
- direct writes are blocked, and the limits hold;
- the migration is safe to run twice.

`NotepadRulesTests` is written but hasn't been run. Checklist: `docs/testing/coach-notepad-np1.md`.

**Files:**
- `Core/Models/CoachNotepad.swift`, `NotepadBlock.swift`, `NotepadScore.swift`
- `Core/Services/NotepadRules.swift`, `NotepadService.swift`
- `Features/Coaching/Notepad/`: `NotepadView`, `NotepadViewModel`, `NotepadScoresCard`,
  `NotepadEntryBar`, `NotepadTextBlockView`, `NotepadTableBlockView`, `NotepadRemoveButton`,
  `ErgOrderSheet`, `NotepadField`
- `AppRoute.notepad` in `RouteHost`; `Tokens.Notepad`
- Ways in: `CoachWorkoutsView` (Open notepad under today's cards), `WorkoutResultsView` (pencil top
  right) and `CoachCalendarView` (pencil on a workout's row)

**Erg order** is the sort button top right, which opens a drag-to-reorder sheet; it replaces dragging
rows on the page itself.


**Server** (`docs/migrations/2026-11-xx-coach-notepad.sql`):
- **`coach_notepads`:** `workout_id` (unique, on delete cascade), `club_id`, `blocks jsonb`
  (ordered: `{id, type: "scores"|"text"|"table", text?, title?, cells?}`), `notes text`,
  `updated_by`, `updated_at`.
- **`coach_notepad_scores`:** `workout_id`, `user_id`, `piece_index`, `split_ms`, `time_ms`,
  `distance_m`, `rate`, `sat_out`, `source` (`typed` | `scanned`), `splits_500_ms int[]` (tests),
  `updated_by`, `updated_at`. The primary key is (`workout_id`, `user_id`, `piece_index`).
- **RLS on both tables:** read and write only when `is_club_coach(club_id)`. No rower policy yet;
  NP4 adds one narrow read for a rower's own scores.
- Check limits on text length, a cap on blocks per page, and a cap on table size (5 columns).

**App:**
- **Models:** `Core/Models/CoachNotepad.swift`, `NotepadBlock.swift`, `NotepadScore.swift`.
- **Service:** `Core/Services/NotepadService.swift` (load a page, save blocks and notes, upsert
  and delete a score).
- **Rules:** `Core/Services/NotepadRules.swift` for the pure parts: the score grid, the order
  Next moves in, time to split and back, and fade.
- **Feature:** `Features/Coaching/Notepad/` with `NotepadView`, `NotepadViewModel`,
  `ScoreGridView`, `ScoreEntryBar` and `NotepadTableBlockView`.

**What gets built:**
- **Ways in:**
  - The Workouts tab's today card gets **Open notepad** (`AppRoute.notepad(UUID)`).
  - The workout results screen gets a Notepad button.
  - A workout's row in the coach Calendar gets one too.
- **Scores table:**
  - One row per rower the workout is for, using the audience the results screen already works
    out. Columns are the workout's reps (`WorkoutRules.totalReps`).
  - Rows the rower posted are filled from their own linked session
    (`WorkoutRules.rowedReps`) and marked with the brand dot. A coach's score for the same box is
    kept separately and shows instead, on the notepad only.
  - Rows are in erg order. The coach can drag a row to match the erg line, and that order is
    saved with the page.
- **Typing:**
  - Tap a box and a `DurationTextField` opens on the decimal pad.
  - A glass bar above the keyboard holds Split / Time (time converts to split from the piece's
    distance), Rate, **Sat out** and **Next**.
  - Next saves and moves down to the next erg, skipping sat-out rows, then on to the first empty
    box of the next piece. The title reads "Next · Dan O.".
- **Blocks:**
  - **Add text** adds a multi-line text block.
  - **Add table** adds a blank table: an editable title and headings, + Row, + Column (up to 5).
  - Any block can be removed. The Scores block can't be removed.
- **Notes:** always the last thing on the page.
- **Saving:** changes save as you go (text is debounced). A page row is only created on the first
  edit, so opening an untouched notepad writes nothing.
- **Two coaches on one page:** the last save wins, per score and per block. Realtime updates can
  come later if the phone tests show coaches sharing pages.
- **Tests:** `NotepadRulesTests`, covering Next order with sat-out rows, time and split
  conversion for distance and time pieces, and the block cap.
- **Checklist:** `docs/testing/coach-notepad-np1.md`.

## Phase NP2 — scanning a monitor (board `CoachNotepadScan`) — built, waiting on the phone tests

Built 2026-11-05. Files: `Core/Models/MonitorRow.swift`, `MonitorParser.intervalRows`,
`NotepadRules.join` / `stitch` / `scannedScores`, `Features/Coaching/Notepad/ScanMonitorView` and
`ScanMonitorViewModel`, `AppRoute.scanMonitor`, the camera column in `NotepadScoresCard`. Tests:
`NotepadScanTests` (21 with the existing OCR tests, all passing):
- every sample photo's interval rows are read against `expected-readouts.json`, and **no reading on
  any of the 16 photos comes out wrong**; readings Vision returned nothing for (the rate on some
  rows of IMG_0647 and IMG_0880) show as known issues, and the coach types those;
- **the three real photos of the 20 × 500m (IMG_0897, 0898, 0899) join into exactly the 20 reps**, in
  order — reps 14–16 on both of the last two screens are kept once.

What the photos taught (so the joining didn't need tuning on invented data):
- PM3/PM5 monitors don't print row numbers, so joining is by the readings themselves.
- Vision sometimes misreads the split's tenth ("1:47.9" as "1:47.0") while the time beside it is right;
  a split is put back from time ÷ (metres ÷ 500) when only its tenth differs.
- A row can come with no rate or no metres at all; a time and a split are enough to keep it.

Checked in the simulator with the sample photos: the scan screen, a one-piece workout read from its
summary row (34:40.1 · 10,000 · 1:44.0 · 29) and filled into the notepad. The multi-screen screen (chips,
highlighted new rows, the overlap line) wasn't seen live: no workout on Dev had several reps.
**Simulator only:** a **Choose a photo** button beside the shutter stands in for the camera (the
simulator has none); it's compiled out of phone builds.

The multi-screen photo sets asked for below are still wanted, to test more monitors and lighting.
Checklist: `docs/testing/coach-notepad-np2.md`.

**Parser.** `MonitorParser` today reads only the summary row under the header. Add
`MonitorParser.intervalRows(_:) -> [MonitorRow]`, reading every data row below it:
- each row's time, metres, split and rate;
- its row number, when the monitor shows one;
- whether it is the summary row.

The existing column logic (`readByColumn`) is reused, so a dim row survives the same way.

**Joining screens.** `NotepadRules.stitch(_ screens: [[MonitorRow]]) -> [MonitorRow]` joins
screens in the order they were taken:
- Pieces appear in time order, and the overlap is matched on the longest run of identical rows,
  so pieces seen on two screens are kept once.
- When rows carry numbers, those decide instead.
- The summary row is dropped from the interval list.

**Screen** (`Features/Coaching/Notepad/ScanMonitorView`): the camera button by a name opens it.
- **Capture:** the camera, with "Only the numbers are kept: the photo is deleted once it's read."
- **Review:**
  - The pieces read so far, with new ones highlighted, and "N of M read".
  - The overlap note ("Pieces 7–8 were on both screens, so they're kept once").
  - **Scan the next screen**, and **Fill Ollie's row**, which writes `source = scanned` scores.
  - Any number can still be corrected afterwards by tapping its box.
- **Privacy:** the image stays in memory only. It is never written to disk, Storage or the photo
  library, and it is released as soon as Vision returns. This uses the existing
  `OCRService.recognizeText`.

**What it needs from you.** Interval results that run over two or three monitor screens. The 18
photos in `docs/ocr-samples/` are single screens. Ask the user for 6–10 multi-screen sets (for
example 8 × 500m and 20 × 250m) before tuning the joining.

**Tests:**
- `MonitorParserTests` for `intervalRows` against the existing samples.
- `NotepadRulesTests` for joining screens: an overlap, no overlap, numbered rows, and a misread
  digit inside the overlap.

**Checklist:** `docs/testing/coach-notepad-np2.md`.

## Phase NP3 — many pieces and tests (boards `CoachNotepadPieces`, `CoachNotepadTest`) — built, waiting on the phone tests

Built 2026-11-05, after NP1 and NP2 passed the phone tests and were merged into `main`. **Needs
`docs/migrations/2026-11-05-coach-notepad-np3.sql`** (checklist step 0). Files: `NotepadSummaryCard`,
`NotepadTestCard`, `ScanButton`; `NotepadScoresCard` gains `isEveryPiece` and metres for timed pieces;
`NotepadRules` gains `summary`, `fadeWindow`, `fadeText`, `metres`/`time`, `splitLabels`, `grouped`,
`test(of:)`; `MonitorParser.splitRows` / `isIntervalTitle`. Tests: 60 notepad, scan and OCR tests pass,
including the real 2k photo (IMG_0593) giving its four 500m splits exactly.

Decided with the user (2026-11-05): **posted rows get their 500m splits by saving them when the rower
posts.** Posts didn't keep them: a segment held only time, metres, split and rate. Now the Log flow
keeps the split rows it reads under a continuous piece (`segments.splits_500_ms`), only while the
metres are still the ones read off the photo, and never for an interval workout (a "count x" or
"/…r" title). Tests posted before this build show "Their post doesn't have 500m splits".

The migration also fixes an NP1 bug found here: a workout set by title alone ("4 x 500m") took the
reps from its title in the app (2026-11-05), but the server counted reps from the pieces only and
refused every score after column 1. The app works before the migration is run (the splits argument is
only sent when there are splits; posted splits are read on their own and left blank if they can't be).

Beyond the boards (for the user to check): a test set with no pieces takes its piece from the test
(a 2k is 2,000 m); a 5k's rows are named "splits" (they're 1,000 m each); with fewer than ten pieces the
fade compares halves and the footnote says so; a test's scan screen lists the splits it read; a timed
piece's box shows its metres with the split under it. Simulator check used a temporary, uncommitted
preview switch (no workout on Dev had over four reps or was a test).

**Many pieces.** When a workout has more reps than fit (more than 4), the Scores block switches
to **Summary | Every piece**:
- **Summary** shows Done (n/m), Avg, Best and Fade (the average of the last five against the
  first five, in `System.error` red when slower by 1.5 s or more).
- A name opens to every piece as tiles, and each tile can be typed into.
- **Every piece** is a sideways-scrolling grid with the names column pinned.

**Tests** (a workout with a `test_key`). The Scores block shows Time, Split and Rate:
- A row opens to its 500m splits (from the rower's own post, or from a scan that read them).
- A typed time shows "Scan the monitor to add 500m splits."
- The footer explains that the club's test board only takes rowers' own posts.

**Timed pieces** (for example 4 × 10′) type and show metres, with the split worked out. This
reuses `WorkoutPiece.kind`.

**Checklist:** `docs/testing/coach-notepad-np3.md`.

## Phase NP4 — the notebook and the rower's card

**Notebook** (board `CoachNotebook`). Workouts → Past → **Notebook** (`AppRoute.notebook`):
- One page per past workout that has a notepad or any posted scores, newest last.
- A squad filter. Swipe or the arrows turn the page, with page dots and "Page n of N".
- **Splits | Against target** (the target from `WorkoutRules.targetSplitMs`; green faster, red
  slower, as on the results screen).
- The squad row, the page's notes, "6 posted · 4 you noted", and **Edit page**.

**One rower** (board `CoachNotebookRower`). Tap a name to see their line across the notebook:
- sessions done, average against target and fastest piece;
- then page by page (title, date, pieces, average, difference from target), each opening its page.

**Rower's Feed card** (boards `RowerCoachScores`, `RowerCoachScoresPosted`):
- A narrow `security definer` function, `my_notepad_scores(workout_id)`, returns only the
  caller's own scores. It never returns text, tables or notes.
- The card shows on the Feed for 3 days after the workout:
  - **Not posted** (`WorkoutService.postedWorkoutIds`): the scores, the line saying they don't
    count, and **Log your session**, which opens the normal Log flow with nothing copied.
  - **Posted:** the same card with no question, just "You posted this session · your average
    1:43.6".
- Shown only when the coach noted at least one score for that rower.

**Checklist:** `docs/testing/coach-notepad-np4.md`.

## Open questions (ask before the phase that needs them)

1. **(NP1) Answered 2026-11-05:** every coach in the club reads and edits every notepad.
2. **(NP2)** Multi-screen monitor photos are needed to tune the joining (see NP2).
3. **(NP4)** Is the rower's card wanted at all, given the notepad is a coach tool? Decision 96
   keeps it; it can be switched off without touching the rest.
