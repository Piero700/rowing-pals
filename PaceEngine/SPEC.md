# Anchor & Impulse Pace Engine — Technical Specification v1.5

**Status:** Ready for implementation
**Supersedes:** v1.4 (adds the prediction range — §5.13, §8.11). v1.3.1: audit fixes — §8.9. v1.3 added perceived effort, age, sex and bodyweight (§2.1, §5.9–5.12)
**Constraints honoured:** no ML, session-summary data only, user-supplied intensity tags

---

## 1. Purpose

Given a Concept2 user's session-summary history and a target test distance, return a
deterministic predicted 500m split, predicted total time, and a confidence score, with
enough component breakdown for the UI to explain the number and enough flags for the UI
to tell the user how to improve it.

---

## 2. The model

Every logged session is treated as one noisy observation of a single latent quantity:
**S2k**, the athlete's maximal 2000m split in seconds per 500m.

```
observed_split(d, T) = S2k + w_T × 5 × log2(d / ref_T) + g_T
```

| Symbol | Meaning |
|---|---|
| `d` | the session's *effort* distance (rep distance for intervals, §6.3) |
| `T` | the user's intensity tag |
| `w_T` | how duration-limited tier `T` is, as a fraction of Paul's Law (1.0 = a maximal test) |
| `ref_T` | the distance at which tier `T`'s offset is quoted — its typical session or rep length |
| `g_T` | tier `T`'s pace gap above maximal 2k pace, **measured at `ref_T`** |

Prediction inverts this to recover `S2k` from an anchor session, then projects out to the
target with Paul's Law at full weight, because a test piece is by definition a maximal
effort:

```
S2k        = anchor_split − w_T × 5 × log2(d / ref_T) − g_T
base_split = S2k + 5 × log2(target / 2000)
```

`ref_T` is the load-bearing detail. Both correction terms are measured from the same
origin, per tier, so the distance discount cannot be applied twice. §8.1 shows what
happens when it is.

### 2.1 Three layers — where each new input belongs

v1.3 adds four inputs. They do not all belong in the same place, and putting them in the
same place is how this class of model goes wrong.

| Layer | Purpose | Inputs it may use |
|---|---|---|
| **Prediction** | Recover S2k from training data | Sessions, tags, **RPE**, bodyweight *trend* (off by default) |
| **Interpretation** | Turn a predicted time into a comparable score | **Weight**, **age** — derived *from* the prediction, never fed back *into* it |
| **Cold start** | Estimate for a user with no usable history | **Age**, **sex**, **weight** — and only here |

**Why age and sex never enter the prediction layer.** The engine anchors on the
athlete's *own* logged sessions. Their age, sex and build are already fully expressed in
the pace they actually rowed. A 55-year-old who rowed a TR 6k at 1:55.5 has a 2k of about
1:45 *as a 55-year-old*; applying an age factor on top would claim they're slower than
their own rowing shows. That is the same double-counting error as §8.1, in a different
variable. The test suite asserts that one history paired with a 22-year-old 95kg man and
a 68-year-old 55kg woman produces identical predicted splits.

**Why RPE does enter it.** RPE isn't a fact about the athlete — it's evidence about the
*session*: how close to their ceiling that particular pace was. That is exactly the
quantity the intensity tag approximates, so it refines the same term.

---

## 3. Input contract

A list of session objects. Unknown keys are ignored. Field aliases are accepted
(snake_case, camelCase, and the Concept2 CSV export headings).

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | no | Echoed back in the anchor block for UI deep-linking |
| `date` | ISO date or datetime | yes | Timezone-naive treated as local |
| `distance_m` | number | yes | Total metres for the session |
| `time_s` | number or `"mm:ss.s"` / `"h:mm:ss.s"` | yes* | |
| `split_s` | number or `"m:ss.s"` | yes* | Average seconds per 500m |
| `stroke_rate` | number | no | Used for tag validation only |
| `tag` | `UT2` \| `UT1` \| `AT` \| `TR` \| `AN` | yes | Case-insensitive |
| `rep_distance_m` | number | no | **Strongly recommended for interval sessions** — see §7.3 |
| `rpe` | number | no | Session RPE, Borg CR10 (1–10). Borg 6–20 values are auto-converted |
| `bodyweight_kg` | number | no | Bodyweight on the day; enables weight-trend detection |

\* At least one of `time_s` / `split_s` must be present; the other is derived. If both are
present and disagree by more than 2%, the engine prefers the value derived from
`time_s / distance_m` (a hand-entered average split can silently exclude rest; total time
over total distance cannot) and warns.

Target distance is a separate positive number (typically 2000 or 5000).

**Athlete profile** — an optional separate object:

| Field | Type | Notes |
|---|---|---|
| `age` | number | 5–110; outside that range it is dropped with a warning |
| `sex` | string | `male` / `female` recognised. Any other answer (`nonbinary`, `other`, …) is accepted and routes to the sex-neutral prior. Answering at all counts as a provided profile |
| `weight_kg` | number | 25–250; current bodyweight |

Every field is optional. An empty profile changes nothing.

---

## 4. Intensity tier constants

| Tier | Load mult. | Offset `g_T` (s) | Reference `ref_T` | Paul weight `w_T` | Expected rate | Expected RPE | Anchor rank |
|---|---|---|---|---|---|---|---|
| AN | 3.0 | 0 | 2,000 m | 1.00 | 28–44 | 9–10 | 1 |
| TR | 2.0 | +8 | 4,000 m | 0.85 | 26–36 | 7–8.5 | 2 |
| AT | 1.5 | +13 | 8,000 m | 0.50 | 20–30 | 5.5–7 | 3 |
| UT1 | 1.2 | +17 | 12,000 m | 0.25 | 18–26 | 4–5.5 | 4 |
| UT2 | 1.0 | +22 | 16,000 m | 0.15 | 14–22 | 2–4 | 5 |

These reproduce the familiar coaching rules of thumb at the distances coaches actually
quote them for — "UT2 is 2k pace + 22" over a normal hour-long row, "TR reps are about 2k
pace" over 1,000m — while remaining mutually consistent. For an athlete with S2k = 1:45.0:

| Session | Model pace | Sanity check |
|---|---|---|
| Maximal 2k (AN) | 1:45.0 | by definition |
| Maximal 6k (AN) | 1:52.9 | Paul's Law from 2k |
| TR 6k | 1:55.5 | 2.6s off a maximal 6k — a hard piece, not a test |
| TR 4 × 1,000m | 1:44.5 | ≈ 2k pace, which is how these are actually rowed |
| AT 8k | 1:58.0 | 2k + 13 |
| UT1 12k | 2:02.0 | 2k + 17 |
| UT2 16k | 2:07.0 | 2k + 22 |

The engine's `_check_tier_coherence` self-test asserts that every tier, evaluated at 0.5×,
1× and 2× its own reference distance, inverts back to exactly the same S2k. Any future
constant change that reintroduces double-counting fails that test.

---

## 5. Pipeline

### 5.1 Ingest and normalise
Parse dates and durations, derive missing split or time, reconcile disagreements, coerce
tags, drop unusable rows with a per-row warning naming the row. Sessions dated after
`as_of` are dropped (`future_dated_session`). Repeated session ids are de-duplicated,
keeping the last copy (`duplicate_sessions_removed`) — a retried upload must not double
the training load, and an edited record is the later write.

### 5.2 Window
Retain sessions in `[as_of − 30 days, as_of]`. Configurable via `window_days`.

### 5.3 Anchor selection
Choose the best available tier by rank, then select within it:

- **AN / TR (maximal tiers):** the session minimising `|log2(effective_distance / target)|`,
  tie-broken on recency. Paul's Law error grows with the distance ratio, so the
  closest-distance effort is the most informative anchor — not merely the longest.
- **AT / UT1 / UT2 (submaximal tiers):** the **duration-weighted median split** across all
  qualifying sessions in the window. A single steady-state row is a noisy estimate of a
  physiological ceiling; the median is what the tier is actually evidence of.

`single_session` mode is available via config for parity testing against v1.0.

### 5.4 Recover S2k, then project
Per §2. Components are returned individually so the UI can show the arithmetic.

### 5.5 Volume modifier (TRIMP-lite)

```
load = Σ (session_duration_minutes × tier_load_multiplier)   over the 30-day window
```

Continuous piecewise-linear interpolation between knots, flat beyond the ends:

| 30-day load | Modifier (s/500m) |
|---|---|
| 0 | +3.0 |
| 600 | 0.0 |
| 1,800 | 0.0 |
| 3,600 | −1.5 |

A step function was rejected: one extra 60-minute row must not flip a displayed
prediction by 2.5 seconds.

The modifier is then **damped by how much history the load figure rests on**:

```
load_confidence  = min(1, session_count / 6)
volume_modifier  = raw_modifier × load_confidence
```

Without this, a user who logs one 2k test and nothing else is told they are detrained and
handed a prediction ~3s/500m slower than the test they rowed yesterday. Sparse *logging*
is not evidence of sparse *training*, and a model that contradicts a measurement the user
just took will not be trusted again. Damped, that user gets 7:01.9 from a logged 7:00.0.

### 5.6 Cross-tier agreement check
Where two or more tiers are represented, compute an S2k from each independently. The
high-to-low spread is `spread_seconds`. Above 6s the tag set is internally inconsistent
(usually mis-tagging) and confidence is cut. This doubles as the calibration harness of
§6.2: a consistently tagged athlete should show a spread near zero.

### 5.7 Clamps

```
floor   = 82.0 + 5 × log2(target / 2000)     # inside the open-weight world record
ceiling = 210.0                              # 3:30/500m — beyond this, assume a data error
```

Breaching either raises a flag and clamps rather than displaying the raw number.

### 5.8 Confidence

Base score by anchor tier and recency, less penalties, clamped to 5–95:

| Basis | Base |
|---|---|
| AN ≤ 14 days | 90 |
| TR ≤ 14 days | 80 |
| AN or TR, 15–30 days | 65 |
| AT | 60 |
| UT1 | 42 |
| UT2 | 35 |

| Penalty | Cost |
|---|---|
| `\|log2(target / anchor_distance)\|` > 2.0 | −15 |
| ... > 3.0 | −25 (instead of −15) |
| Fewer than 6 sessions in window | −12 |
| Fewer than 3 sessions in window | −20 (instead of −12) |
| No session in the last 10 days | −10 |
| Anchor stroke rate outside tier range | −10 |
| Tier agreement spread > 6s | −10 |
| AN/TR anchor of ambiguous interval structure (§6.3) | −15 |

Banding: `≥75 → High`, `≥50 → Medium`, else `Low`. With no usable anchor the engine
returns `Insufficient Data` and a null prediction — never a fabricated number.

The ratio thresholds are set at 2.0 and 3.0 doublings (4× and 8×) so that a 6k test used
to predict a 2k — a standard, well-regarded substitution — is not penalised, while a 500m
anchor used to predict a 5k is.

v1.3 adds two penalties:

| Penalty | Cost |
|---|---|
| Anchor RPE contradicts its tag (§5.9) | −10 |
| Recent sessions feel harder than their zones (§5.10) | −8 |

### 5.9 Perceived effort — refining the anchor

RPE places a session within its tier. A row that felt harder than that zone normally
does means the athlete was nearer their ceiling than the tag assumes, so the true gap to
maximal pace is smaller and S2k is slower than the raw inversion suggests:

```
rpe_correction = clamp(1.2 × (rpe − tier_rpe_midpoint), −3.0, +3.0)
S2k           += rpe_correction
```

The cross-tier slope is about 3.4 s per RPE point (22 s of offset across ~6.5 RPE
points). Within a tier it is damped to 1.2 s, because RPE is subjective and
mood-sensitive and is reported once per session.

A UT2 16k at 2:07.0 gives a 2k of 7:02.5 at RPE 3, 7:07.3 at RPE 4 and 6:57.7 at RPE 2.

**AN is exempt.** An all-out test is the measurement itself; RPE on an AN piece can only
reveal a wrong tag (via the contradiction check below), never that the athlete is faster
or slower than the time they just rowed.

**Coverage scaling.** For submaximal anchors the correction is multiplied by the share of
the tier's duration that carries a usable rating, so one rated row among nineteen moves
the prediction by about 0.13s rather than 2.4s.

**Contradictions are flagged, not applied.** If RPE sits more than 2.5 points from the
tier midpoint — a UT2 row at RPE 9, say — that's evidence the *tag* is wrong. The
correction is set to zero, `anchor_tag_rpe_mismatch` is raised, and confidence drops.
Bending the pace by seven points' worth of offset would corrupt the prediction instead
of questioning the input.

For submaximal anchors the RPE used is the duration-weighted median across the tier's
*consistently rated* sessions — the same aggregation as the split, with contradicted
ratings excluded so a single mis-tagged row cannot become the median.

### 5.10 Perceived effort — fatigue

Averaged across the last 7 days, RPE in excess of each session's tier midpoint is read
as accumulated fatigue. Above +1.5 the engine raises `elevated_recent_effort`, lowers
confidence and tells the user a test now would likely come in slow.

This affects **confidence and advice only, never pace.** The anchor's own RPE already
adjusts S2k in §5.9; letting fatigue move the pace too would count the same signal twice
whenever the anchor is recent.

### 5.11 Bodyweight

**Weight-adjusted score (interpretation layer).** Concept2's published formula, verified
against the [Concept2 weight adjustment calculator](https://www.concept2.com/training/weight-adjustment-calculator):

```
Wf             = (bodyweight_lb / 270) ^ 0.222
corrected_time = actual_time × Wf
```

A 7:00.0 at 80 kg becomes 6:22.1 weight-adjusted (Wf = 0.9098).

**Weight trend (prediction layer, off by default).** The same exponent implies raw erg
performance scales as weight^−0.222, so a lighter athlete should row a slower raw score.
The engine detects bodyweight change between the weigh-in nearest the anchor date and the
most recent weigh-in — both from dated session logs, never the undated profile weight —
and *can* apply:

```
weight_trend_correction = projected_split × ((w_now / w_anchor) ^ −0.222 − 1) × sensitivity
```

`sensitivity` defaults to **0.0**. The Concept2 formula compares *different athletes*;
applied to *one athlete's change* it assumes every kilo gained or lost was working
muscle. Losing 4 kg of fat doesn't cost erg speed the way losing 4 kg of muscle does,
and the engine can't tell which happened. With the term off, a change of ≥1.5 kg still
raises `weight_change_not_applied` so the UI can mention it. Enable at 1.0 for the full
Concept2 effect, or lower if cohort data shows an attenuated one.

### 5.12 Age grading and the cold-start prior

**Age grading (interpretation layer).** There's no official Concept2 age-grading formula.
The nearest standard, the USRowing handicap (zero at age 27), has been
[shown to over-credit older rowers](https://analytics.rowsandall.com/2018/03/08/aging-and-rowing-performance-part-4-a-look-at-the-usrowing-age-handicapping-system/)
against the Concept2 rankings. So from age 27 up the engine's curve is **fitted to the
Concept2 rankings** (v1.4, §7.6): each 10-year band's median ranked 2k over the 19–29
median, averaged across men and women and the 2025 and 2026 seasons, placed at the band's
midpoint (`prior_age_curve`). Between knots it is linear, starting from 0% at 27; past
the last knot it continues at the last segment's slope.

| Age | Expected-time adjustment |
|---|---|
| under 18 | +2.5% per year below 18, on top of the 18-year-old value (seed) |
| 18 → 27 | linear from +6% to 0% (seed) |
| 27 | 0% (reference) |
| 35 | +5.87% |
| 45 | +8.92% |
| 55 | +11.90% |
| 65 | +17.39% |
| 75 | +26.52% |
| 85 | +42.67% (then +1.6% per year) |

Under 27 is still the seed rule: ranked juniors are a strongly selected group (the 12–18
median is as fast as the 19–29 median), which says nothing about a typical 16-year-old.

`age_graded_time = actual_time ÷ age_factor`. At 55 the factor is 1.119, so a 7:00.0
grades to 6:15.3.

**Cold-start prior.** A user with a profile and *no rowing history at all* gets a
**Population Estimate** instead of a blank. A user whose history is merely older than the
30-day window does not — their own stale result beats a population number — and gets
`Insufficient Data` with `history_outside_window`:

```
prior_2k = baseline(sex) × (reference_kg / weight_kg) ^ 0.222 × age_factor(age)
```

| Baseline (age 27) | 2k | Reference weight |
|---|---|---|
| Male | 6:58.6 | 82 kg |
| Female | 8:03.5 | 68 kg |
| Sex-neutral (any other answer, or blank with other fields given) | 7:31.1 | 75 kg |

The baselines are the **median** all-weights 19–29 ranked 2k, averaged over the 2025 and
2026 seasons (§7.6): "mid-pack among rowers who log a ranked 2k", which is fitter than the
general population. The reference weights are assumed, not fitted. The
result is shaped so the UI can't mistake it for a prediction: its own confidence band
(`Population Estimate`, numeric 15), a null anchor, the flags `population_estimate` and
`prior_from_concept2_rankings`, and an `estimate_basis` list explaining each adjustment.
The first logged session replaces it.

Weight applies at full strength here, unlike in §5.11's trend term, because comparing
different people is exactly what the Concept2 formula was built for.

### 5.13 Prediction range (v1.5)
Every anchored prediction carries a **± in seconds**: how far it could plausibly be off.
It is built from the same evidence the confidence score reads, one term per independent
source of doubt, added in quadrature, in seconds per 500m:

| Term | Value |
|---|---|
| Anchor zone (base) | AN 0.75, TR 1.0, AT 1.5, UT1 2.0, UT2 2.25 |
| Stale anchor | 0.05 per day older than 14 days |
| Projection | 0.75 per doubling from the anchor's distance (AN/TR) or from 2000m (submaximal, already converted) to the target |
| Zones disagree | half the cross-tier spread, when 2+ zones are logged |
| Thin history | 1.5 × (1 − load_confidence) |
| Possible intervals | 3.0 when `interval_structure_ambiguous` |
| Tag contradicted | 1.0 each for the anchor's rate and its RPE contradicting its tag |

```
split_range = sqrt(sum(term²))
total_range = split_range × target / 500
```

A fresh all-out 2k with a full month of logging gives ±3 s over 2k; UT2 sessions alone, ±9 s.
Population estimates and empty results carry no range (`null`): a population estimate is
about people like the rower, not the rower.

---

## 6. Output contract

```jsonc
{
  "schema_version": "anchor-impulse/1.3",
  "generated_for_date": "2026-09-17",
  "target_distance_m": 2000,
  "predicted_split_seconds": 105.0,
  "predicted_split_formatted": "1:45.0",
  "predicted_total_time_seconds": 419.99,
  "predicted_total_time_formatted": "7:00.0",
  "predicted_split_range_seconds": 0.75,
  "predicted_total_time_range_seconds": 3.0,
  "confidence_score": "High",
  "confidence_numeric": 80,
  "confidence_factors": [ { "label": "Recent race-pace work", "delta": 80 } ],
  "anchor": { "tier": "TR", "session_ids": ["6k-tr"], "date": "2026-09-08",
              "days_ago": 9, "split_seconds": 115.49, "split_formatted": "1:55.5",
              "effective_distance_m": 6000, "method": "closest_distance" },
  "load": { "trimp_lite": 1281.8, "session_count": 21, "window_days": 30,
            "raw_modifier_seconds": 0.0, "load_confidence": 1.0,
            "modifier_seconds": 0.0 },
  "components": { "anchor_split": 115.49, "paul_adjustment": -2.49,
                  "intensity_offset": -8.0, "rpe_correction": 0.0,
                  "two_k_equivalent": 105.0, "projection_to_target": 0.0,
                  "weight_trend_correction": 0.0, "volume_modifier": 0.0,
                  "clamp_adjustment": 0.0 },
  "effort": { "sessions_with_rpe": 21, "anchor_rpe": 7.8, "recent_rpe_excess": 0.0 },
  "athlete": { "age": 21, "sex": "male", "weight_kg": 80,
               "bodyweight_at_anchor_kg": null, "used_in_prediction": false },
  "interpretation": {
    "weight_adjusted": { "factor": 0.9098, "total_time_formatted": "6:22.1",
                         "method": "Concept2: Wf = (lbs / 270) ^ 0.222" },
    "age_graded": { "factor": 1.04, "reference_age": 27,
                    "total_time_formatted": "6:43.8",
                    "method": "fitted to Concept2 rankings medians (2025-26), not an official standard" }
  },
  "diagnostics": { "two_k_equivalent_by_tier": { "TR": 105.0, "AT": 105.0,
                                                 "UT1": 105.0, "UT2": 105.0 },
                   "spread_seconds": 0.0, "tiers_represented": 4 },
  "flags": [],
  "warnings": [],
  "recommendations": []
}
```

`components` reads top to bottom as the arithmetic, so the UI can render a "how we got
this" panel. `athlete.used_in_prediction` is `false` unless the weight-trend term fired —
the UI should not imply that age or sex shaped the number. `recommendations` exists so a
Low confidence score is actionable rather than merely discouraging.

Population estimates (§5.12) return the same top-level keys with `confidence_score:
"Population Estimate"`, `anchor: null`, and an extra `estimate_basis` array.

---

## 7. Known limitations

**7.1 Paul's Law degrades outside roughly 0.5×–2.5× the reference distance.** It is an
empirical rule of thumb, not a physiological law. Predicting a 5000m from a 500m anchor
spans a 10× ratio; the engine returns a number, flags it, and cuts confidence, but the
number should not be trusted.

**7.2 The constants are unvalidated.** Every offset and weight in §4 is a seed value
chosen for internal coherence and agreement with coaching convention — not a fitted one.
Before launch, run `diagnose_history()` across a real cohort and tune until the
cross-tier spread collapses. This is the single highest-value pre-launch task, and the
diagnostic block already ships the per-tier residuals needed to do it.

**7.3 Interval sessions are the largest remaining source of error.** An `8 × 500m` AN
session has a total distance of 4,000m but an effort distance of 500m. Treating it as a
4,000m maximal effort understates the athlete badly — in the test suite, by 15 seconds
per 500m. With summary-only data this is not reliably detectable, so the engine accepts
an optional `rep_distance_m` and, where an AN or TR session lacks one and exceeds a
plausible continuous-test distance, flags `interval_structure_ambiguous` and demotes
confidence. **Capturing rep distance at logging time is a product decision worth making;
it is a single optional field that removes the biggest error term in the model.**

**7.4 Tags are self-reported.** The stroke-rate check catches gross mis-tagging only. The
engine never silently retags a user's session — it flags, explains, and lowers confidence.

**7.5 Fatigue is read, not modelled.** RPE now detects sustained excess effort (§5.10)
and warns, but there's still no pace term for acute load: a user who logs a 30k the day
before a test gets the same predicted time as one who rested, with a warning only if they
also reported high RPE.

**7.6 The cold-start prior and age curve are fitted to a self-selected group.** Since
v1.4 both come from the Concept2 Online Rankings (2000m RowErg, 2025 and 2026 seasons,
all countries, non-adaptive), read on 2026-10-05 into
`PaceEngine/data/concept2_2k_rankings_percentiles.csv` and reproduced by
`python3 fit_population_prior.py`, which prints every constant. Its limits:

- **Who ranks.** Rowers who chose to log a ranked 2k are fitter than people in general,
  so the baselines are mid-pack *for that group*. The median (not the 25th or 75th
  percentile) was chosen, by Piero, 2026-10-05.
- **Under 27 is not fitted.** The ranked junior median is as fast as the 19–29 one, a
  selection effect, so the seed rule stays.
- **The age curve is pooled.** Men's and women's ratios are averaged; the 80–89 knot
  rests on few rowers (women's 80–89 median moved 1:17 between seasons).
- **Weight is not fitted.** Only lightweight/heavyweight is published, not bodyweight.
  The 19–29 lightweight/heavyweight median ratio (men 1.033, women 1.038) is consistent
  with Concept2's 0.222 exponent, which stays; the 82/68 kg reference weights are assumed.
- **The reference age stays 27** while the baselines come from the 19–29 band.

Refresh by re-reading the rankings pages into the CSV, re-running the script and
pasting its output into `EngineConfig`.

**7.7 Weight trend can't tell fat from muscle.** Hence off by default (§5.11). Logging
body-composition data, or simply asking the user whether a weight change was
intentional, would be needed to apply it safely.

**7.8 RPE scale confusion.** Values 11–20 are assumed to be Borg 6–20 and converted;
values strictly between 10 and 11 are rejected.
A user on the CR10 scale can't enter 11+, so this is unambiguous above 10 — but a Borg
6–20 user entering 6–10 will be misread as CR10. If the app lets users pick a scale,
store it with the value rather than inferring it.

**7.9 The range is a seed, not a measured error.** The §5.13 terms are chosen to agree with
coaching experience (a fresh test pins a 2k to a few seconds; easy mileage alone, to about
ten), not fitted. After launch, compare each prediction with the test the rower then posts
and tune the terms until about two thirds of results land inside the range.

---

## 8. Deviations from v1.0, with rationale

### 8.1 Step 3 formula — corrected (breaking)

v1.0 specified:

```
Predicted_Split = Anchor_Split + 5 × log2(Target / Anchor_Distance) + Pace_Offset
```

This applies Paul's Law across the anchor-to-target distance ratio and *then* applies a
pace offset that is itself quoted relative to 2k pace. The distance discount is counted
twice whenever the anchor is a long submaximal row.

Worked example — a rower whose true 2k is 1:45.0, rowing 15,000m UT2 at 2:06.9:

```
v1.0:  126.9 + 5 × log2(2000 / 15000) + (−22)
     = 126.9 + (−14.54) + (−22)
     = 90.4 s/500m  →  predicted 2k of 6:03.3
```

That is **58 seconds fast** on a 7:00 rower. Every user whose only recent data is
steady-state volume — which at V1 launch will be most of them — receives a fantasy
prediction, and the error *scales with how much training they do*: the longer the anchor
row, the more absurd the number. That inverts the incentive the app exists to create.

v1.2 recovers S2k correctly:

```
v1.2:  S2k        = 126.9 − 0.15 × 5 × log2(15000/16000) − 22 = 105.0
       base_split = 105.0 + 5 × log2(2000/2000)                = 105.0 s/500m
                  →  predicted 2k of 7:00.0   ✓
```

### 8.2 Offsets are now anchored to a per-tier reference distance
An intermediate draft fixed §8.1 by weighting the Paul's Law term per tier, but left the
offsets quoted at each tier's typical session distance while measuring the Paul term from
2,000m. That reintroduced the same double-count in the AT and TR tiers — smaller, and far
harder to see: a coherent 6k anchor predicted a 2k of 6:17 instead of 7:00. Adding
`ref_T`, so both correction terms share an origin, is what actually closes it. The
coherence test in §4 exists to stop it recurring.

### 8.3 UT1 was absent from the v1.0 anchor priority list
Inserted at rank 4, between AT and UT2. Without it, a user with only AT and UT1 sessions
falls through to UT2 and gets no anchor at all.

### 8.4 TRIMP-lite bands recalibrated
v1.0's bands (`<150`, `150–400`, `>400`) do not match rowing volume. Three 40-minute
steady rows a week is roughly 515 units over 30 days; a club athlete training ten times a
week clears 3,000. Under v1.0 essentially every real user lands in the `>400` "aerobic
bonus" band, so the modifier does no work at all. The v1.2 knots put the maintenance
plateau across genuine recreational-to-club volume.

### 8.5 Step function replaced with linear interpolation, and damped
See §5.5.

### 8.6 Submaximal anchors aggregated rather than picked singly
See §5.3.

### 8.7 Anchor selection prefers the closest distance, not the longest
v1.0 selected the *longest* qualifying session. Since Paul's Law error grows with the
anchor-to-target ratio, that systematically picks the worst available anchor.

### 8.8 Average stroke rate is now consumed
v1.0 listed it as available but never used it. It now validates tags (§5.8), which is
cheap and catches the most common data-quality failure.

---

### 8.9 v1.3.1 audit fixes

| # | Bug | Observed before fix | Fix |
|---|---|---|---|
| 1 | A contradicted RPE could become a tier's median | +3.0s, no flag | Contradicted ratings excluded from the median |
| 2 | One rated session steered a whole tier | +2.4s from 1 of 19 rows | Correction scaled by rated-duration coverage |
| 3 | Stale real result replaced by a guess | a 6:30 test → "7:20 Population Estimate" | Prior only when there is no history at all |
| 4 | RPE moved an all-out test | a 7:00.0 test → 6:54.7 (RPE 8) / 7:04.3 (RPE 10) | AN exempt from RPE correction |
| 5 | RPE 10.5 read as Borg | 10.5 → RPE 3.2 | (10, 11) rejected |
| 6 | Profile weight vs weigh-ins read as a trend | flagged a 6kg "loss" across two scales | Trend uses dated weigh-ins only |
| 7 | Weight trend scaled from the training split | 0.620 vs 0.562 s/500m | Applied to the projected split |
| 8 | Duplicate sessions double-counted | doubled load and median weight | De-duplicated by id, last copy wins |
| 9 | Crash when every tier rating was contradicted | TypeError (introduced by fix 1, caught by suite) | Display RPE kept, coverage forced to 0 |
| 10 | Clamped (impossible) result shown at Medium confidence | "5:28.0, Medium" from a typo'd split | Any clamp caps confidence at Low |

### 8.10 v1.4 fitted population prior
The cold-start baselines (7:20.0 / 8:20.0 → 6:58.6 / 8:03.5) and the age curve from 27
up are fitted from the Concept2 rankings medians (§5.12, §7.6). The flag
`prior_is_seed_data` is renamed `prior_from_concept2_rankings`. No anchored prediction
changes: the prior is used only with no history at all, and age only feeds the prior and
the age-graded score.

### 8.11 v1.5 prediction range
Adds `predicted_split_range_seconds` and `predicted_total_time_range_seconds` (§5.13) so the
coach view can show "7:20 ±9s". Nothing else changes: every v1.4 prediction, confidence
score and flag is identical.

## 9. Test coverage

v1.5 adds 6 checks for the range (±3 s from a fresh all-out 2k, ±9 s from UT2 alone, wider
when projecting further, with a thin history and with contradictory tags, and no range on a
population estimate or an empty result).

v1.4 adds 2 checks for the fitted age curve (passes through every knot, continuous at
the reference age; 90 total). v1.3.1 added 11 audit regressions, one per bug in §8.9. v1.3 added 34, most importantly: identical predictions across wildly
different demographics; symmetric, capped RPE corrections; RPE contradictions flagged
rather than applied; fatigue affecting confidence but not pace; the weight factor
matching Concept2's formula exactly; weight trend off by default; a monotonic age curve;
labelled population estimates; and a user who answers the sex question with anything
other than male/female receiving the same level of service as one who doesn't.

The v1.2 suite covered: tier coherence at three distances
per tier; the v1.0-vs-v1.2 divergence; round-tripping a logged 2k test; a physiologically
consistent athlete at 2k and 5k; detection of a deliberately contradictory tag set; cold
start; empty and `None` history; zero and negative distances; non-numeric target; history
outside the window; future-dated rows; malformed rows; interval ambiguity with and
without `rep_distance_m`; stroke-rate mismatch; world-record clamping; split/time
disagreement; Concept2 CSV column aliases; duration parsing and formatting including
minute and hour carry; UT1-only and UT2-only histories; and JSON-serialisability.

Fixtures are generated through the forward model rather than hand-written. The first
draft's hand-written fixture asserted a 6k rowed at 2k pace, which masked §8.2 for a full
test cycle.
