# OCR sample photos

Real photos of a Concept2 PM5 monitor, used by `MonitorParserTests` (in
`Rowing PalsTests/`) to verify `Core/Services/MonitorParser.swift` actually
reads the screen correctly. Task 09's own bar: below roughly 70% of these
producing all four fields (elapsed time, distance, /500m split, stroke
rate) correctly, the parser needs more work before anything gets built on
top of it.

## What to add here

- `.jpg`/`.jpeg`/`.png`/`.heic` files, any name.
- Real PM5 screens, not screenshots or mockups — the whole point is testing
  against the glare, angle and lighting variation a phone camera actually
  sees in a gym.
- **Varied lighting**: bright gym lighting, dim early-morning lighting, a
  screen with glare on it.
- **Varied values**: different elapsed times (including both `M:SS.d` and
  `H:MM:SS` — the monitor switches format past an hour), different
  distances, different stroke rates. `MonitorParser` finds fields by
  *position*, not by pattern-matching digits, so the more layouts and value
  shapes this set covers, the more it actually proves.
- A dozen or so is a reasonable starting set — enough to be a real
  percentage, not so many it's a chore to collect.

## Expected readouts (the regression test)

`expected-readouts.json` holds, for every photo here, what the monitor actually shows: the
summary row (time, distance, split, rate), the rep distance from the title, and the
per-interval rows for reference. `Rowing PalsTests/OCRRegressionTests.swift` runs the real
pipeline over each photo and fails with a per-photo, per-field message if a reading changes.
Fields the pipeline already got wrong are listed under `baselineFailures` and show as known
issues. **When you add a photo, add its entry to `expected-readouts.json` too**; the test
fails if a photo has no entry. Results and how to run it:
`docs/testing/ocr-regression-2026-10-27.md`.

## Running the print-out test

`Rowing PalsTests/MonitorParserTests.swift` reads every image in this
folder directly (not bundled as test resources), runs it through
`OCRService` + `MonitorParser`, and prints each file's extracted values plus
the overall pass rate. Run it via Xcode's Test navigator, or
`xcodebuild test`.
