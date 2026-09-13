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

## Running the test

`Rowing PalsTests/MonitorParserTests.swift` reads every image in this
folder directly (not bundled as test resources), runs it through
`OCRService` + `MonitorParser`, and prints each file's extracted values plus
the overall pass rate. Run it via Xcode's Test navigator, or
`xcodebuild test`.
