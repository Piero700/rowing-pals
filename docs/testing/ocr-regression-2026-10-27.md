# OCR regression test — baseline, 2026-10-27

A test that runs the app's real OCR pipeline (`OCRService` → `MonitorParser`, the same calls the
Review screen makes) over every monitor photo in `docs/ocr-samples/` and checks each reading
against what the monitor actually shows.

- Expected values: `docs/ocr-samples/expected-readouts.json` (one entry per photo)
- Test: `Rowing PalsTests/OCRRegressionTests.swift` (+ `OCRRegressionFixture.swift`, which reads the JSON)
- No Xcode project change: like the existing `MonitorParserTests`, the test reads the photos and the
  JSON straight from `docs/ocr-samples/` on disk (the simulator can read the Mac's files), and the
  new Swift files sit in the synchronised `Rowing PalsTests/` folder.
- The baseline below was taken with no OCR code changed. The two parser weaknesses it found were
  then fixed the same day; see **Fix: all 16 photos now read correctly** further down.

## What is compared

For each photo, five fields:

| Field | What it is |
|---|---|
| time (`elapsedTimeMs`) | the summary row's time |
| distance (`distanceM`) | the summary row's metres |
| split (`splitMs`) | the summary row's /500m |
| rate | the summary row's s/m |
| rep distance (`repDistanceM`) | from the title: 500 for "20x500m/:20r", none for a single piece or timed reps |

**Interval rows are written down but not compared.** The parser only reads the summary row today, so
there is nothing to compare them with. They are in the JSON (`intervals.rows`), ready for when the
parser learns to read them.

## Baseline results, before the fix (iPhone 17 Pro simulator, iOS 26.5)

**13 of 16 photos read every field correctly. 3 photos have wrong fields (6 wrong fields in total).**

| Photo | Workout | time | distance | split | rate | rep distance |
|---|---|---|---|---|---|---|
| IMG_0046 | 100m | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_0593 | 2000m | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_0625 | 1100m | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_0630 | 1x10:00/2:00r | ✅ | ✅ | ✅ | ✅ | ✅ |
| **IMG_0647** | 1500m | ❌ nothing | ❌ nothing | ❌ nothing | ❌ nothing | ✅ |
| IMG_0648 | 2x1000m/2:00r | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_0856 | 5000m | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_0860 | v3000m/3:00r…4 | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_0866 | 10x1000m/:20r | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_0880 | 60 min (1:00:03.7) | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_0888 | 3x12:00/3:00r | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_0895 | 5000m | ✅ | ✅ | ✅ | ✅ | ✅ |
| **IMG_0897** | 20x500m/:20r (PM3) | ✅ | ✅ | ✅ | ✅ | ❌ none (should be 500 m) |
| **IMG_0898** | 20x500m/:20r (PM3) | ✅ | ✅ | ✅ | ✅ | ❌ none (should be 500 m) |
| IMG_0899 | 20x500m/:20r (PM3) | ✅ | ✅ | ✅ | ✅ | ✅ |
| IMG_1007 | 61 min (1:01:28.9) | ✅ | ✅ | ✅ | ✅ | ✅ |

By field: time 15/16, distance 15/16, split 15/16, rate 15/16, rep distance 14/16.

The test's exact failure messages, first run:

```
IMG_0647.jpeg — time: expected 5:21.7 (321700 ms), read nothing
IMG_0647.jpeg — distance: expected 1500 m, read nothing
IMG_0647.jpeg — split: expected 1:47.2 (107200 ms), read nothing
IMG_0647.jpeg — rate: expected 21 s/m, read nothing
IMG_0897.jpeg — rep distance: expected 500 m, read none
IMG_0898.jpeg — rep distance: expected 500 m, read none
```

These six are now the **baseline**: they are listed under `baselineFailures` in the JSON and show in
Xcode as known issues (grey, "Expected Failure"), so the test is green. The test fails if:

- a field that reads correctly today starts reading wrong (a regression),
- a baseline field starts reading correctly (it tells you to remove it from `baselineFailures`, so the
  baseline doesn't go stale), or
- a photo in `docs/ocr-samples/` has no entry in the JSON (or the JSON names a missing photo).

Second run with the baseline in place: **passed** (2 tests, 16 photo cases, 3 shown as expected failures).

### Why those three fail (diagnosis only, nothing changed)

I dumped Vision's raw text for these photos (macOS Vision with the same settings, so it may differ
slightly from the simulator's):

- **IMG_0647**: the monitor is small in the frame and the screen is dim. Vision reads the summary time
  `5:21.7` as `5213` (colon and decimal point lost, `7` read as `3`), and reads the split and rate as one
  item, `1:47.2 21`. `MonitorParser` needs exactly two colon-shaped values in the row, finds one, and
  drops the **whole row**, so all four fields come back empty even though distance, split and rate were
  read correctly. Changing that all-or-nothing rule would turn this photo into 3 of 4 right.
- **IMG_0897 / IMG_0898**: on the PM3 the small "x" in the title is read as a zero: `200500m/:20r`,
  `200500ml20r`. The rep-distance pattern needs an `x`, so it finds nothing. IMG_0899 is a close-up of
  the same screen, and there the title reads correctly.
- On the same photos the raw text also shows some interval-row misreads (for example IMG_0897's first
  rep time read as `1:45.5`, not `1:46.5`), which will matter once interval rows are parsed.

## Fix: all 16 photos now read correctly (2026-10-27)

`MonitorParser` was changed for the two weaknesses above, and the baseline is now empty: no photo
has a known failure. Simulator raw text was dumped first. It differs slightly from the macOS dump
above: the simulator reads IMG_0647's time as `5217`, not `5213`.

**Before → after (iPhone 17 Pro simulator, iOS 26.5):**

| Photo | time | distance | split | rate | rep distance |
|---|---|---|---|---|---|
| IMG_0647 | ❌ nothing → ✅ 5:21.7 (confidence 0.40, flagged on Review) | ❌ → ✅ 1500 | ❌ → ✅ 1:47.2 | ❌ → ✅ 21 | ✅ none → ✅ none |
| IMG_0897 | ✅ → ✅ | ✅ → ✅ | ✅ → ✅ | ✅ → ✅ | ❌ none → ✅ 500 m |
| IMG_0898 | ✅ → ✅ | ✅ → ✅ | ✅ → ✅ | ✅ → ✅ | ❌ none → ✅ 500 m |
| the other 13 | ✅ → ✅ | ✅ → ✅ | ✅ → ✅ | ✅ → ✅ | ✅ → ✅ |

By field: time 16/16, distance 16/16, split 16/16, rate 16/16, rep distance 16/16. `OCRRegressionTests`
passes with every `baselineFailures` list empty, and `MonitorParserTests`, `PhotoClassificationTests`
and `ReviewSessionTests` pass too (42 test cases).

What changed in the parser:

1. **A damaged summary row degrades field by field.** When the summary row doesn't read as exactly
   two colon values and two plain numbers, the parser now takes the four column positions from the
   first clean interval row below it. It then places each summary value in its nearest column, keeping
   a value only if it has that column's shape. A row that reads cleanly still goes through the old path
   unchanged. If there's no clean interval row to take positions from (a one-row table), the result is
   empty, as before.
2. **Merged values get their own position.** Parts of one observation (`1:47.2 21`) are now placed by
   where their characters sit in the box, not both at its middle. A split and rate glued with no space
   (`1:47.221`) are split apart, which is safe because a real time or split never has more than one
   digit after the decimal point.
3. **A time that lost its colon is rebuilt only if it checks out.** `5217` is read as 5:21.7 and kept
   only if it fits split × distance ÷ 500. All 16 sample rows show the monitor truncates the split: the
   real time is never below that product, and at most 0.1 s per 500 m (plus 0.1 s) above it. For
   IMG_0647 the window is 5:21.5–5:22.0, so `5217` (5:21.7) is kept and the macOS misread `5213`
   (5:21.3) would be left empty. A rebuilt time gets confidence 0.4, under the Review sheet's 0.5 line,
   so it is always highlighted for the rower to check.
4. **A rep distance whose "x" was read as 0 is recovered only when the table backs it.** `200500m` is
   split as count + `0` + distance (20, 500) and kept only if count × distance equals the summary's total
   (20 × 500 = 10,000) or the distance appears in at least two interval rows. Exactly one reading must
   pass. Single pieces such as `10000m` or `21097m` never split into a valid count and distance.

Added beyond the brief, for you to check: the 0.4 confidence on a rebuilt time (so Review flags it), and
the no-space split+rate case (`1:47.221`). Neither occurs in the 16 photos except the flag on IMG_0647.

Still not handled: if Vision drops a summary value entirely, the row has fewer than four values. The
parser then takes the first interval row as the summary, as it did before.

## Expected values that need your check

Every summary-row value was read from the photo and then checked by arithmetic: interval times add up
to the total time, and time ÷ distance × 500 gives the split shown. All 16 summary rows are consistent,
so **no compared value is marked uncertain**.

What is uncertain is *which rep numbers* some interval lists show. These aren't compared yet:

| Photo | What's uncertain | My reading |
|---|---|---|
| IMG_0866 | Only 7 of the 10 reps are on screen. Which 7? | Reps 4–10: the list ends with the `r186` rest line, so it looks scrolled to the bottom. The photo can't prove it. |
| IMG_0897 | Which 8 reps are shown | Reps 1–8 |
| IMG_0898 | Which 8 reps are shown | Reps 9–16 |
| IMG_0899 | Which 7 reps are shown | Reps 14–20 (the last 3 of IMG_0898 repeat at its top) |

The 0897/0898/0899 numbering is inferred: those three photos are the same 20x500m workout, and
reps 1–8 + 9–16 + 17–20 add up to 34:40.2 against the monitor's 34:40.1 (0.1 s of rounding).

Two small notes, no action needed:

- IMG_0625: its split times add up to 3:46.4, but the monitor's total says 3:46.3. That's rounding of
  the tenths, and the expected value is the monitor's 3:46.3.
- IMG_0898: the last row's time is blurred (`1:4?.7`). For a 500 m rep, time equals split (1:43.7),
  and IMG_0899 shows the same row clearly as 1:43.7.

## How to rerun it

### In Xcode, click by click

1. Open `Rowing Pals.xcodeproj` (double-click it in Finder, in the `Rowing Pals` folder).
2. At the top of the window, check that the scheme menu (left of the device name) says **Rowing Pals**,
   and that the device menu next to it shows a simulator, e.g. **iPhone 17 Pro**. If it shows your
   phone or "Any iOS Device", click it and choose **iPhone 17 Pro** under iOS Simulators.
3. Press **⌘6**, or click the diamond-shaped icon at the top of the left sidebar, to open the
   **Test navigator**.
4. Expand **Rowing PalsTests**, then find **OCRRegressionTests**. You can type `OCRRegression` in the
   filter box at the bottom of the sidebar to find it quickly.
5. Hover over **OCRRegressionTests** and click the small ▶︎ (play) button that appears on the right
   of its row. The build and the test take about 2–3 minutes. The simulator doesn't need to be open.
6. When it finishes, a green tick means nothing regressed. Expand **readsTheSummaryRow(of:)** to see
   one row per photo. Since the fix, every photo is a green tick (the baseline is empty; before the fix,
   IMG_0647, IMG_0897 and IMG_0898 showed a grey "expected failure" icon).
7. If something goes red, click the red row. The message names the photo, the field, the expected
   value and what was read, e.g. `IMG_0593.jpeg — split: expected 1:49.5 (109500 ms), read 1:49.0 (109000 ms)`.
   To see every message at once, press **⌘9** (Report navigator) and click the latest **Test** entry.

### From the command line

From the project folder (the one containing `Rowing Pals.xcodeproj`):

```bash
xcodebuild test -project "Rowing Pals.xcodeproj" -scheme "Rowing Pals" -destination "platform=iOS Simulator,name=iPhone 17 Pro" -only-testing:"Rowing PalsTests/OCRRegressionTests"
```

It prints `** TEST SUCCEEDED **` at the end when nothing regressed. A failure prints
`Issue recorded: IMG_… — <field>: expected …, read …` lines.

(This needs `Debug.xcconfig` in the project folder, as any build does. A git worktree doesn't have
it, because it's gitignored. For this run I symlinked the main checkout's copy into the worktree;
the symlink is untracked and not committed.)

## When you add a photo or fix the OCR

- **New photo**: drop it in `docs/ocr-samples/` and add an entry to `expected-readouts.json` (copy an
  existing one and change the values). The test fails until the entry exists.
- **OCR fix**: run the test. If a fix makes a baseline field read correctly, the test fails with
  "now reads correctly … Remove "<field>" from its baselineFailures". Remove it and the test locks in
  the improvement.
