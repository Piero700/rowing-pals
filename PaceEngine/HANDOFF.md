# Pace Engine — Handoff Brief for Claude Code

**Project:** Rowing Pals (SwiftUI, iOS)
**Task:** Port the Anchor & Impulse pace engine from the Python reference to Swift, prove the
port is exact against the golden vectors, then wire it into the app.

Files in this folder:

| File | What it is |
|---|---|
| `SPEC.md` | The specification. Explains *why* every rule exists. Read §2, §2.1 and §5 before writing code. |
| `pace_engine.py` | The **reference implementation**. Where SPEC.md and this file disagree, this file wins. |
| `golden_vectors.json` | 38 end-to-end cases + 34 helper-function checks, generated from the reference. The Swift port must reproduce all of them. |
| `make_golden_vectors.py` | Regenerates the vectors. Run with `python3 make_golden_vectors.py` from this folder. |
| `HANDOFF.md` | This brief. |

---

## Ground rules

1. **Port, don't redesign.** The maths has been through two rounds of bug-hunting. Do not
   "simplify", re-derive or re-tune any formula or constant. If something looks wrong,
   stop and report it with a failing case — don't silently change behaviour.
2. **The golden vectors are the acceptance test.** The port isn't done until every vector
   passes. A vector that fails is a porting bug until proven otherwise.
3. **Pure logic, no UI, no I/O in the engine.** Foundation only. No SwiftUI, no SwiftData,
   no networking, no `Date()` calls inside the engine — `asOf` is always passed in.
4. **Work in two phases with a stop between them** (below). Report after each.

---

## Phase 1 — Port the engine (stop and report when done)

### Structure

Create a **local Swift package** in the repo, e.g. `Packages/PaceEngine`, added to the app
target as a local package dependency. Keeping it out of the app target means its tests run
with `swift test` in seconds, no simulator needed.

```
Packages/PaceEngine/
  Package.swift
  Sources/PaceEngine/
    Tier.swift              // Tier struct + the five TIERS constants
    EngineConfig.swift      // every tunable, defaults identical to Python
    Inputs.swift            // SessionInput, AthleteProfile (typed, not dictionaries)
    Validation.swift        // _normalise_session / _normalise_athlete / RPE / sex / dedupe
    AnchorSelection.swift   // _select_anchor, _weighted_median, _tier_rpe
    Model.swift             // _normalise_to_reference, RPE correction, load, weight, age, prior
    Confidence.swift        // _score_confidence + the clamp cap
    Interpretation.swift    // weight-adjusted and age-graded scores
    Formatting.swift        // format_seconds
    PacePredictor.swift     // public predict(...) entry point
    Prediction.swift        // Codable output, mirroring SPEC.md §6
  Tests/PaceEngineTests/
    GoldenVectorTests.swift
    Resources/golden_vectors.json   // copy of the file in this folder
```

Public API:

```swift
public enum PacePredictor {
    public static func predict(
        history: [SessionInput],
        targetDistance: Double,
        asOf: Date,
        calendar: Calendar = .current,
        config: EngineConfig = .default,
        athlete: AthleteProfile? = nil
    ) -> Prediction
}
```

`SessionInput` takes typed values: `id: String`, `date: Date`, `distanceM: Double`,
`timeS: Double?`, `splitS: Double?`, `strokeRate: Double?`, `tag: Tier.Name`,
`repDistanceM: Double?`, `rpe: Double?`, `bodyweightKg: Double?`. Python's field aliases
and "mm:ss.s" string parsing are not needed; the OCR layer hands over numbers. Validation
must still reject zero/negative/NaN values exactly as the Python does, because the vectors
test that.

### Porting traps (each one silently breaks vectors if missed)

- **Day arithmetic must use calendar days, not seconds.** Python compares `date` objects.
  In Swift compute `calendar.dateComponents([.day], from: calendar.startOfDay(for: a),
  to: calendar.startOfDay(for: b)).day`. Dividing a `TimeInterval` by 86,400 gives the
  wrong answer across the March and October clock changes, and the UK has both.
- **Weighted median:** sort by value, walk the running weight total, and return the first
  value where the running total is ≥ half the total weight. If total weight ≤ 0, return
  the element at index `count / 2`.
- **Maximal-tier anchor tie-break:** minimise `(abs(log2(target / effectiveDistance)),
  -dayOrdinal)`, so the closest distance wins, then the most recent.
- **Single-session submaximal mode** (config only): maximise `(distance, dayOrdinal)`.
- **De-duplication keeps the *last* occurrence** of each id, and runs before parsing.
- **RPE:** values strictly between 10 and 11 are invalid; 11 to 20 convert as
  `(v − 6) / 1.4`. **AN is exempt from the RPE pace correction.** Submaximal corrections
  are multiplied by rated-duration coverage, and contradicted ratings are excluded from
  the median.
- **`sexDeclared`:** any non-blank sex/gender answer makes the profile non-empty, even one
  that maps to neither male nor female. A user who answers "non-binary" must get the
  same service as one who answers "male".
- **Population prior only when there is no parsed history at all.** History that is merely
  outside the 30-day window returns Insufficient Data.
- **Clamped results cap confidence at Low** (score `min(score, mediumThreshold − 1)`).
- **Weight trend uses dated session weigh-ins only**, never the profile weight, and scales
  the *projected* split.
- **Rounding:** keep full precision internally and round only when building the output.
  Python rounds half-to-even while Swift's `.rounded()` rounds half away from zero, so
  compare within the tolerance below, never with `==`.
- **`format_seconds` quantises to 0.1s before splitting into h/m/s**, otherwise 419.96s
  renders as "6:60.0".
- **Flag strings are API.** Use exactly the Python spellings
  (`interval_structure_ambiguous`, `population_estimate`, …). The app keys UI off them.

### Golden vector test

`GoldenVectorTests` loads `golden_vectors.json` and, for every entry in `cases`:

1. Builds `EngineConfig.default`, applying `config_overrides` (keys are Python snake_case
   names; map them explicitly).
2. Converts `history` rows into `SessionInput`, parsing `date` as a calendar day in a fixed
   UTC calendar (pass that calendar into `predict` too, so the test is
   timezone-independent).
3. Calls `predict` with `as_of`, `target_distance_m` and `athlete`.
4. Compares against `expected`:
   - numbers within `tolerance.seconds` (0.02);
   - `flags` as a **set**;
   - `confidence_score`, `anchor_tier`, `anchor_method`, the formatted strings and
     `anchor_session_ids` exactly;
   - `components` and `two_k_equivalent_by_tier` key by key.

Also test each entry in the `parsing` block (`format_seconds`, `weight_adjustment_factor`,
`age_performance_factor`, `normalise_rpe`).

Use parameterised tests so each case reports by name. **Phase 1 is done when `swift test`
passes all 38 cases and all 34 parsing checks.** Report the result, and list any case
that needed a judgement call to pass.

---

## Phase 2 — Integrate into Rowing Pals (only after Phase 1 is reported)

### What feeds the engine

- **Erg sessions only.** Water sessions never go into the engine; their splits aren't
  comparable. (The meters leaderboard combining erg and water is a separate system and
  isn't affected.)
- **Use the work segment, not the session total.** A post can hold warmup, main and
  cooldown monitor photos plus a session total. Feed the engine the main segment(s) only.
  A 2k test plus warmup and cooldown, sent as one 6k "AN" session, would be read as an
  all-out 6k and badly understate the athlete.
- **Intervals:** when OCR reads a PM5 interval summary, set `repDistanceM` from the rep
  distance. This removes the model's single largest error source (SPEC §7.3) at no cost
  to the user.
- `id` = the post's stable UUID. `date` = the session's local calendar day.

### New inputs the UI needs to collect

| Input | Where | Notes |
|---|---|---|
| Zone tag (UT2/UT1/AT/TR/AN) | Post confirmation screen | Required for erg sessions. Pre-select **AN** when the app has auto-detected a test piece. |
| RPE | Post confirmation screen | Optional. **CR10 only, 0–10**, so the Borg-scale ambiguity can't arise. |
| Age, gender, weight | Profile | All optional. Gender is a free choice including "other" and "prefer not to say", stored as the user's answer, not forced into male/female. |
| Bodyweight on the day | Optional, later | Only matters if weight trend is ever enabled (it's off by default). |

### Where predictions appear

- **Tests tab:** a prediction card per standard distance (2k, 5k, 6k…). Show predicted time
  and split, the confidence band, and the `recommendations` list.
- **"How we got this" sheet:** render `components` top to bottom as the arithmetic.
- **Visually distinct states:**
  - `High` / `Medium` / `Low`: a normal prediction card with a confidence badge.
  - `Population Estimate`: clearly labelled as based on similar people, not on you. Never
    styled like a real prediction.
  - `Insufficient Data`: an empty state with the recommendation text.
- **Predictions never enter leaderboards.** Leaderboards show confirmed results only.

### Decisions to bring back to Piero before building UI for them

- **Weight-adjusted scores conflict with the app's "no weight class anywhere" rule.** The
  engine computes them, but they're effectively a weight-class comparison. Don't surface
  them on any leaderboard or public view without explicit sign-off.
- **Age-graded scores** are fitted to the Concept2 rankings medians from age 27 up (seed
  rule below 27). If shown, label them as indicative.
- **Population Estimate** values are fitted from the Concept2 rankings medians since v1.4
  (SPEC §7.6). Piero chose to keep the cold-start estimate hidden for now (2026-10-05):
  `PredictionService.showsPopulationEstimate` in the app.

### Performance

The engine is pure arithmetic over at most a few hundred rows. Call it synchronously
when a post is saved or the profile changes and cache the result per distance. It needs
no background work.

---

## Changing the engine later

The Python file stays the source of truth. To change a constant or rule:

1. Change `pace_engine.py` and run `python3 pace_engine.py` (88 checks must pass).
2. Run `python3 make_golden_vectors.py`.
3. Copy the new `golden_vectors.json` into the Swift test resources.
4. Port the change and get `swift test` green.

Never edit the Swift side alone; the two will drift and the vectors stop meaning anything.

## v1.5 (2026-10-05): prediction range
`predicted_split_range_seconds` and `predicted_total_time_range_seconds` (SPEC.md §5.13): a
± in seconds, shown in Coaching as "7:20 ±9s". Ported to `Packages/PaceEngine`
(`PredictionRange.swift`); golden vectors regenerated (38 cases, all reproduced).

