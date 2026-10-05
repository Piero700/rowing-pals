"""
Anchor & Impulse Pace Engine — v1.3.1
=====================================

Deterministic, heuristic prediction of Concept2 test-piece times from session-summary
training logs. No machine learning, no stroke-by-stroke data, no network calls.

Public API
----------
    predict_test_piece(history, target_distance, as_of=None, config=None,
                       athlete=None) -> dict
    diagnose_history(history, as_of=None, config=None) -> dict

`history` is any iterable of session dicts; `target_distance` is metres; `athlete` is an
optional profile dict (age, sex, weight). The return value is a JSON-serialisable dict
(see SPEC.md §6).

Three layers, and why the separation matters
--------------------------------------------
New in v1.3: perceived effort, age, sex and bodyweight. They do NOT all belong in the
same place, and putting them in the same place is how this kind of model goes wrong.

    PREDICTION      recovers S2k from training data.
                    RPE enters here (it is evidence about intensity).
                    Bodyweight TREND may enter here, off by default (§ weight notes).
                    Age and sex never enter here.

    INTERPRETATION  turns a predicted time into a comparable score.
                    Weight-adjusted and age-graded scores live here.
                    Derived FROM the prediction; never fed back INTO it.

    COLD START      a population estimate when there is no training data at all.
                    Age, sex and weight enter here, and only here.
                    Always labelled as an estimate, never as a prediction.

The reason age and sex are excluded from the prediction layer is structural, not
political: the engine anchors on the athlete's OWN logged sessions. Their age and sex are
already fully expressed in the pace they actually rowed. Multiplying by a demographic
factor would count the same information twice — the exact failure mode v1.2 was built to
eliminate. A test asserts that two identical histories with wildly different demographics
produce byte-identical predicted splits.

The one idea you need to hold to read this file
-----------------------------------------------
Every observed session is modelled as:

    observed_split(d, T) = S2k + w_T * 5 * log2(d / ref_T) + g_T

    S2k   the athlete's maximal 2000m split — the single latent quantity we want
    w_T   how duration-limited tier T is (1.0 for an all-out test, ~0.15 for steady state)
    ref_T the distance at which tier T's intensity offset is quoted
    g_T   tier T's pace gap above maximal 2k pace, AT ref_T

Everything else is bookkeeping. We invert that equation to recover S2k from an anchor
session, then project S2k out to the target distance with Paul's Law at full weight
(a test piece is by definition a maximal effort, so w = 1).

The two traps this structure exists to avoid
--------------------------------------------
1.  Applying Paul's Law across the anchor-to-target ratio *and* adding a pace offset that
    is itself quoted relative to 2k pace. That counts the distance discount twice and
    produces fantasy predictions from long steady rows. See SPEC.md §7.1.

2.  Fixing trap 1 by weighting the Paul term, but leaving the offsets quoted at each
    tier's *typical session distance* while measuring the Paul term from 2000m. That
    reintroduces the same double-count for the middle tiers, just smaller and harder to
    see. `ref_distance_m` is what closes it: the offset and the Paul term are now measured
    from the same origin, per tier.

Every model constant below is a seed value chosen to be internally consistent and to
match standard coaching rules of thumb. None of them are fitted. `diagnose_history()` is
the harness for fitting them against a real cohort; see SPEC.md §6.2. The exception is the
cold-start population prior, fitted from the Concept2 rankings (SPEC.md §7.6).
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field, replace
from datetime import date, datetime, timedelta
from typing import Any, Iterable, Mapping, Sequence

SCHEMA_VERSION = "anchor-impulse/1.4"

__all__ = [
    "SCHEMA_VERSION",
    "EngineConfig",
    "Tier",
    "TIERS",
    "predict_test_piece",
    "diagnose_history",
    "parse_duration",
    "format_seconds",
    "weight_adjustment_factor",
    "age_performance_factor",
]


# --------------------------------------------------------------------------------------
# Tier constants
# --------------------------------------------------------------------------------------

@dataclass(frozen=True)
class Tier:
    """Physiological constants for one training intensity zone.

    load
        TRIMP-lite intensity multiplier, applied to session duration in minutes.
    offset
        Seconds per 500m that this tier sits above maximal 2000m pace, measured at
        `ref_distance_m`. Positive: submaximal work is slower. Quoting it at a stated
        reference distance rather than "in general" is what keeps it from overlapping
        with the Paul's Law term.
    ref_distance_m
        The distance at which `offset` is quoted — the tier's typical session or rep
        length, which is how coaches state these numbers ("UT2 is 2k pace + 22" means
        over a normal hour-long UT2 row, not over 2000m).
    paul_weight
        How strongly this tier's pace decays with distance, as a fraction of Paul's Law.
        1.0 = fully duration-limited (a genuine maximal test). Low for steady state,
        whose pace is pinned by a lactate/HR ceiling and is nearly flat from 8k to 20k.
    rate_lo / rate_hi
        Plausible average stroke rate. Outside this range the tag is probably wrong; we
        say so and cut confidence, but we never silently retag a user's own session.
    rpe_lo / rpe_hi
        Plausible session RPE on the Borg CR10 scale (1-10). Used two ways: to corroborate
        the tag, and to place the session within its tier (see `_rpe_offset_correction`).
    rank
        Anchor selection priority, lower is better.
    """

    name: str
    load: float
    offset: float
    ref_distance_m: float
    paul_weight: float
    rate_lo: float
    rate_hi: float
    rpe_lo: float
    rpe_hi: float
    rank: int

    @property
    def rpe_mid(self) -> float:
        return (self.rpe_lo + self.rpe_hi) / 2.0


# Seed calibration. Verified mutually consistent for a 1:45.0 2k athlete: see the
# `_check_tier_coherence` self-test, which asserts every tier recovers the same S2k from
# the pace it implies.
TIERS: dict[str, Tier] = {
    #            load  off    ref     w     rate     RPE     rank
    "AN":  Tier("AN",  3.0,  0.0,  2000.0, 1.00, 28.0, 44.0, 9.0, 10.0, 1),
    "TR":  Tier("TR",  2.0,  8.0,  4000.0, 0.85, 26.0, 36.0, 7.0,  8.5, 2),
    "AT":  Tier("AT",  1.5, 13.0,  8000.0, 0.50, 20.0, 30.0, 5.5,  7.0, 3),
    # UT1 was missing from the v1.0 priority list; without it an AT+UT1 athlete falls
    # through to UT2 and gets no anchor at all. See SPEC.md §8.3.
    "UT1": Tier("UT1", 1.2, 17.0, 12000.0, 0.25, 18.0, 26.0, 4.0,  5.5, 4),
    "UT2": Tier("UT2", 1.0, 22.0, 16000.0, 0.15, 14.0, 22.0, 2.0,  4.0, 5),
}

MAXIMAL_TIERS = ("AN", "TR")
SUBMAXIMAL_TIERS = ("AT", "UT1", "UT2")

# Field aliases accepted on input, mapped to canonical names.
_FIELD_ALIASES = {
    "date": ("date", "Date", "session_date", "sessionDate", "timestamp"),
    "distance_m": ("distance_m", "distance", "Distance", "total_distance",
                   "totalDistance", "Total Distance (meters)", "meters"),
    "time_s": ("time_s", "time", "Time", "total_time", "totalTime",
               "Total Time", "duration", "elapsed"),
    "split_s": ("split_s", "split", "Split", "average_split", "averageSplit",
                "Average Split (seconds/500m)", "avg_split", "pace"),
    "stroke_rate": ("stroke_rate", "strokeRate", "Average Stroke Rate", "spm",
                    "rate", "avg_stroke_rate"),
    "tag": ("tag", "Tag", "zone", "Zone", "intensity", "intensity_tag"),
    "rep_distance_m": ("rep_distance_m", "repDistance", "rep_distance",
                       "interval_distance", "piece_distance"),
    "id": ("id", "ID", "session_id", "sessionId", "uuid"),
    # Session RPE on the Borg CR10 scale (1-10). A 1-20 Borg value is detected and
    # converted; see `_normalise_rpe`.
    "rpe": ("rpe", "RPE", "perceived_effort", "perceivedEffort", "effort",
            "session_rpe", "sessionRpe", "borg"),
    # Bodyweight at the time of the session, in kg. Enables trend detection without
    # requiring the caller to keep a separate weight log.
    "bodyweight_kg": ("bodyweight_kg", "bodyweightKg", "weight_kg", "weightKg",
                      "bodyweight", "weight"),
}

ATHLETE_ALIASES = {
    "age": ("age", "age_years", "ageYears"),
    "sex": ("sex", "gender"),
    "weight_kg": ("weight_kg", "weightKg", "bodyweight_kg", "bodyweightKg",
                  "weight", "bodyweight"),
}

# Accepted sex values, normalised. Anything else (including "other", "nonbinary" or a
# blank) falls back to the sex-neutral prior rather than being coerced into a category,
# because this value is only ever used for a population estimate and a wrong guess is
# worse than an explicitly wider one.
_SEX_MALE = {"m", "male", "man"}
_SEX_FEMALE = {"f", "female", "woman"}


# --------------------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------------------

@dataclass(frozen=True)
class EngineConfig:
    """All tunable behaviour. Nothing outside this class and TIERS should need editing."""

    window_days: int = 30
    paul_constant: float = 5.0            # seconds per 500m per doubling of distance
    reference_distance_m: float = 2000.0  # the latent quantity's reference distance

    # Volume modifier knots: (30-day TRIMP-lite load, seconds added to split).
    # Linear interpolation between knots, flat beyond the ends. See SPEC.md §7.3-7.4 for
    # why the v1.0 bands (<150 / 150-400 / >400) were discarded.
    load_knots: tuple[tuple[float, float], ...] = (
        (0.0, 3.0),
        (600.0, 0.0),
        (1800.0, 0.0),
        (3600.0, -1.5),
    )

    # Physiological sanity clamps, expressed at the 2000m reference and scaled by Paul's Law.
    floor_split_at_reference: float = 82.0   # inside the open-weight world record (~1:23.9)
    ceiling_split: float = 210.0             # 3:30/500m; slower than this is a data error

    # Confidence
    high_threshold: int = 75
    medium_threshold: int = 50
    recent_anchor_days: int = 14
    stale_history_days: int = 10
    min_sessions_comfortable: int = 6
    min_sessions_minimum: int = 3
    tier_spread_tolerance_s: float = 6.0

    # Distance-ratio guards. Paul's Law is an empirical rule of thumb; its error grows with
    # the anchor-to-target ratio. 2.0 doublings (a 4x ratio) is the point at which a
    # coach would start to distrust it — a 6k anchor for a 2k target is well inside that.
    ratio_warn_log2: float = 2.0
    ratio_severe_log2: float = 3.0

    # Interval-structure heuristic: an AN/TR session longer than this, with no declared
    # rep_distance_m, is probably intervals rather than one continuous effort.
    interval_suspicion_m: dict[str, float] = field(
        default_factory=lambda: {"AN": 3000.0, "TR": 10000.0}
    )

    # Reconciliation tolerance between a supplied split and one derived from time/distance.
    split_mismatch_tolerance: float = 0.02

    # "median" (default, robust) or "single_session" (v1.0 parity: longest qualifying row).
    submaximal_anchor_method: str = "median"

    # --- Perceived effort (RPE) --------------------------------------------------------
    #
    # RPE places a session within its tier. A row that felt harder than that zone usually
    # feels means the athlete was working nearer their ceiling than the tag implies, so
    # the true intensity gap is smaller and the recovered S2k is correspondingly slower.
    #
    # The cross-tier slope is roughly 3.4 s per RPE point (22s of offset spread over ~6.5
    # RPE points). Using that within a tier would be far too aggressive for a subjective,
    # mood-sensitive, once-per-session number, so it is damped hard and capped.
    rpe_sensitivity: float = 1.2          # seconds of offset per RPE point of deviation
    rpe_max_correction: float = 3.0       # absolute cap on the correction, seconds
    rpe_contradiction_points: float = 2.5  # beyond this, treat as a tag contradiction
    # Mean RPE excess across the last N days, above which the athlete is read as carrying
    # fatigue. Affects confidence and advice only — never the pace, to avoid
    # double-counting the per-session correction above.
    fatigue_window_days: int = 7
    fatigue_rpe_excess: float = 1.5

    # --- Bodyweight -------------------------------------------------------------------
    #
    # Concept2's published weight adjustment: Wf = (lbs / 270) ^ 0.222, corrected time =
    # actual time x Wf. Implies raw performance scales as weight ^ -0.222.
    # https://www.concept2.com/training/weight-adjustment-calculator
    weight_adjust_exponent: float = 0.222
    weight_adjust_reference_lb: float = 270.0
    #
    # Applying that exponent to one athlete's weight CHANGE is a different and much weaker
    # claim than using it to compare two athletes. The formula assumes the extra mass does
    # useful work; 4kg of added fat does not make anyone faster. Default 0.0 (disabled).
    # Set to 1.0 to apply the full Concept2 exponent to weight trend, or something like
    # 0.3-0.5 if a cohort shows a real but attenuated effect. See SPEC.md §7.7.
    weight_trend_sensitivity: float = 0.0
    weight_trend_min_kg: float = 1.5      # ignore noise below this much change

    # --- Cold-start population prior ---------------------------------------------------
    #
    # FITTED from the Concept2 Online Rankings, 2000m RowErg, 2025 and 2026 seasons: the
    # MEDIAN ranked 2k by sex and age band (data/concept2_2k_rankings_percentiles.csv,
    # reproduced by fit_population_prior.py). "Mid-pack among rowers who log a ranked 2k",
    # a self-selected and fitter-than-average group. Every result built from these is
    # labelled "Population Estimate". See SPEC.md §7.6.
    prior_reference_age: float = 27.0
    prior_male_2k_seconds: float = 418.6      # 6:58.6, all-weights 19-29 median
    prior_female_2k_seconds: float = 483.5    # 8:03.5, all-weights 19-29 median
    # Not fitted: assumed typical bodyweights for the baselines above. The rankings'
    # lightweight/heavyweight medians are consistent with the 0.222 exponent.
    prior_male_reference_kg: float = 82.0
    prior_female_reference_kg: float = 68.0
    prior_confidence_numeric: int = 15
    # Age curve from the reference age up, as (age, fractional slowdown vs the reference
    # age): each 10-year band's median over the 19-29 median, pooled across sexes and
    # seasons, at the band's midpoint. Linear between knots, from (reference age, 0), and
    # extended past the last knot at the last segment's slope.
    prior_age_curve: tuple[tuple[float, float], ...] = (
        (35.0, 0.0587), (45.0, 0.0892), (55.0, 0.119),
        (65.0, 0.1739), (75.0, 0.2652), (85.0, 0.4267),
    )

    # Reproduce the original v1.0 Step 3 arithmetic, for A/B measurement only.
    legacy_v1_formula: bool = False


DEFAULT_CONFIG = EngineConfig()


# --------------------------------------------------------------------------------------
# Parsing helpers
# --------------------------------------------------------------------------------------

def parse_duration(value: Any) -> float | None:
    """Parse a duration into seconds. Returns None rather than raising.

    Accepts: 410.2, "410.2", "6:50.2", "1:23:45.6", "6:50".
    Rejects: negatives, zero, NaN, inf, nonsense.
    """
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        seconds = float(value)
        return seconds if math.isfinite(seconds) and seconds > 0 else None

    text = str(value).strip()
    if not text:
        return None
    # Tolerate a trailing unit and comma decimal separators from European locales.
    text = text.rstrip("s").strip().replace(",", ".")

    parts = text.split(":")
    if len(parts) > 3:
        return None
    try:
        numbers = [float(part) for part in parts]
    except ValueError:
        return None
    if any(not math.isfinite(n) or n < 0 for n in numbers):
        return None

    if len(numbers) == 1:
        total = numbers[0]
    elif len(numbers) == 2:
        total = numbers[0] * 60.0 + numbers[1]
    else:
        total = numbers[0] * 3600.0 + numbers[1] * 60.0 + numbers[2]
    return total if total > 0 else None


def parse_date(value: Any) -> date | None:
    """Parse a date or datetime into a date. Returns None rather than raising."""
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value

    text = str(value).strip()
    if not text:
        return None
    # Normalise the trailing Z that ISO 8601 allows but fromisoformat historically did not.
    if text.endswith(("Z", "z")):
        text = text[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(text).date()
    except ValueError:
        pass
    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d"):
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            continue
    return None


def format_seconds(seconds: float | None) -> str | None:
    """Render seconds as m:ss.s, or h:mm:ss.s past the hour."""
    if seconds is None or not math.isfinite(seconds):
        return None
    sign = "-" if seconds < 0 else ""
    # Quantise BEFORE decomposing. Decomposing first and rounding the seconds field last
    # renders 419.96s as "6:60.0" — the carry never reaches the minutes field.
    remaining = round(abs(float(seconds)), 1)
    hours = int(remaining // 3600)
    remaining -= hours * 3600
    minutes = int(remaining // 60)
    remaining -= minutes * 60
    if hours:
        return f"{sign}{hours}:{minutes:02d}:{remaining:04.1f}"
    return f"{sign}{minutes}:{remaining:04.1f}"


def _pluck(raw: Mapping[str, Any], canonical: str) -> Any:
    """Read a field from a raw session dict, tolerating known aliases."""
    for key in _FIELD_ALIASES[canonical]:
        if key in raw and raw[key] is not None:
            return raw[key]
    return None


def _to_float(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(str(value).strip().replace(",", "."))
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) else None


def _normalise_rpe(value: Any) -> float | None:
    """Coerce a perceived-effort value onto the Borg CR10 scale (1-10).

    Accepts the classic Borg 6-20 scale too, since some clubs use it and a user typing
    "15" means something quite different from a CR10 "15". Values above 10 are mapped by
    the standard approximation CR10 = (Borg20 - 6) / 1.4, which puts 6 -> 0 and 20 -> 10.
    Anything outside both scales is discarded rather than clamped, because a nonsense
    number here would quietly bias the pace correction.
    """
    number = _to_float(value)
    if number is None:
        return None
    # (10, 11) is neither scale: CR10 tops out at 10 and Borg 6-20 is reported in whole
    # numbers from 11 up in this range. A "10.5" is a CR10 user overshooting, and
    # converting it as Borg would read a maximal effort as RPE 3.2. Reject it.
    if 10.0 < number < 11.0:
        return None
    if 11.0 <= number <= 20.0:
        number = (number - 6.0) / 1.4
    if not (0.0 <= number <= 10.0):
        return None
    return number


def _normalise_sex(value: Any) -> str | None:
    """Normalise to 'male', 'female', or None.

    None covers absent, 'other', non-binary and anything unrecognised. It is a legitimate
    answer, not a failure: it routes to the sex-neutral prior with a wider band, which is
    more honest than assigning a category the user did not choose.
    """
    if value is None:
        return None
    text = str(value).strip().lower()
    if text in _SEX_MALE:
        return "male"
    if text in _SEX_FEMALE:
        return "female"
    return None


@dataclass(frozen=True)
class Athlete:
    """Demographic profile. Every field is optional and the engine degrades gracefully."""

    age: float | None = None
    sex: str | None = None
    weight_kg: float | None = None
    # True when the user answered the sex/gender question at all, including with a value
    # outside male/female. Without this, a user who answers "nonbinary" and nothing else
    # reads as an empty profile and gets less than a user who answered "male" — the same
    # question answered differently must not produce a different level of service.
    sex_declared: bool = False

    @property
    def is_empty(self) -> bool:
        return (self.age is None and self.weight_kg is None
                and self.sex is None and not self.sex_declared)


def _normalise_athlete(raw: Any, warnings: list[str]) -> Athlete:
    """Parse an athlete profile dict. Never raises; implausible values are dropped."""
    if raw is None:
        return Athlete()
    if isinstance(raw, Athlete):
        return raw
    if not isinstance(raw, Mapping):
        warnings.append("athlete profile was not an object; ignored")
        return Athlete()

    def pluck(canonical: str) -> Any:
        for key in ATHLETE_ALIASES[canonical]:
            if key in raw and raw[key] is not None:
                return raw[key]
        return None

    age = _to_float(pluck("age"))
    if age is not None and not (5.0 <= age <= 110.0):
        warnings.append(f"athlete age {age:g} is outside 5-110; ignored")
        age = None

    weight = _to_float(pluck("weight_kg"))
    if weight is not None and not (25.0 <= weight <= 250.0):
        warnings.append(f"athlete weight {weight:g}kg is outside 25-250; ignored")
        weight = None

    sex_raw = pluck("sex")
    sex = _normalise_sex(sex_raw)
    sex_declared = sex_raw is not None and str(sex_raw).strip() != ""
    if sex is None and sex_declared:
        # Not an error. Recorded so the output can explain the wider prior band.
        warnings.append(
            "athlete sex not recognised as male/female; using the sex-neutral prior"
        )

    return Athlete(age=age, sex=sex, weight_kg=weight, sex_declared=sex_declared)


# --------------------------------------------------------------------------------------
# Session model
# --------------------------------------------------------------------------------------

@dataclass(frozen=True)
class Session:
    id: str
    day: date
    distance_m: float
    time_s: float
    split_s: float
    tag: str
    stroke_rate: float | None
    rep_distance_m: float | None
    effective_distance_m: float
    interval_ambiguous: bool
    rate_mismatch: bool
    rpe: float | None = None
    rpe_mismatch: bool = False
    bodyweight_kg: float | None = None

    @property
    def duration_minutes(self) -> float:
        return self.time_s / 60.0

    @property
    def tier(self) -> Tier:
        return TIERS[self.tag]

    @property
    def rpe_deviation(self) -> float:
        """Signed RPE distance from the tier's expected midpoint. 0.0 when RPE is absent."""
        if self.rpe is None:
            return 0.0
        return self.rpe - self.tier.rpe_mid


def _normalise_session(
    raw: Mapping[str, Any],
    index: int,
    config: EngineConfig,
    warnings: list[str],
) -> Session | None:
    """Validate and canonicalise one raw session. Returns None if unusable.

    Every rejection path appends a warning naming the row, so a user with a broken import
    can be told which session to fix rather than being handed a silent gap.
    """
    if not isinstance(raw, Mapping):
        warnings.append(f"row {index}: not an object, skipped")
        return None

    session_id = str(_pluck(raw, "id") or f"row-{index}")

    day = parse_date(_pluck(raw, "date"))
    if day is None:
        warnings.append(f"{session_id}: unparseable or missing date, skipped")
        return None

    tag_raw = _pluck(raw, "tag")
    tag = str(tag_raw).strip().upper() if tag_raw is not None else ""
    if tag not in TIERS:
        warnings.append(f"{session_id}: unrecognised intensity tag {tag_raw!r}, skipped")
        return None

    distance = _to_float(_pluck(raw, "distance_m"))
    if distance is None or distance <= 0:
        warnings.append(f"{session_id}: distance must be a positive number, skipped")
        return None

    time_s = parse_duration(_pluck(raw, "time_s"))
    split_s = parse_duration(_pluck(raw, "split_s"))

    # Derive whichever of time/split is absent. The positive-distance check above is what
    # makes this division safe; the guard is kept explicit because this is the line that
    # would bite if that check ever moved.
    derived_split = (time_s / distance) * 500.0 if time_s else None
    if split_s is None and derived_split is None:
        warnings.append(f"{session_id}: needs at least one of time or average split, skipped")
        return None
    if split_s is None:
        split_s = derived_split
    elif derived_split is not None:
        divergence = abs(derived_split - split_s) / derived_split
        if divergence > config.split_mismatch_tolerance:
            # Prefer the derived value: a user-entered average split can silently exclude
            # rest intervals, whereas total time over total distance cannot.
            warnings.append(
                f"{session_id}: stated split {format_seconds(split_s)} disagrees with "
                f"time/distance ({format_seconds(derived_split)}) by "
                f"{divergence:.0%}; using time/distance"
            )
            split_s = derived_split
    if time_s is None:
        time_s = split_s * distance / 500.0

    if not (0 < split_s < config.ceiling_split * 2):
        warnings.append(f"{session_id}: implausible split {split_s:.1f}s, skipped")
        return None

    stroke_rate = _to_float(_pluck(raw, "stroke_rate"))
    if stroke_rate is not None and not (0 < stroke_rate < 60):
        stroke_rate = None

    tier = TIERS[tag]
    rate_mismatch = (
        stroke_rate is not None and not (tier.rate_lo <= stroke_rate <= tier.rate_hi)
    )

    # Interval handling. A declared rep distance is trusted — that one optional field
    # removes the largest error source in the whole model. Without it, a maximal-tier
    # session too long to be one continuous effort is flagged rather than guessed at.
    rep_distance = _to_float(_pluck(raw, "rep_distance_m"))
    if rep_distance is not None and rep_distance <= 0:
        rep_distance = None

    interval_ambiguous = False
    if rep_distance is not None:
        effective_distance = min(rep_distance, distance)
    else:
        effective_distance = distance
        suspicion = config.interval_suspicion_m.get(tag)
        if suspicion is not None and distance > suspicion:
            interval_ambiguous = True

    # Perceived effort. A value far from the tier's expected band is treated as a
    # contradiction rather than as a pace correction — a UT2 row reported at RPE 9 is
    # almost certainly a mis-tag, and feeding that through as a 7-point offset shift
    # would corrupt the prediction instead of questioning the tag.
    rpe = _normalise_rpe(_pluck(raw, "rpe"))
    rpe_mismatch = False
    if rpe is not None:
        deviation = abs(rpe - tier.rpe_mid)
        if deviation > config.rpe_contradiction_points:
            rpe_mismatch = True

    bodyweight = _to_float(_pluck(raw, "bodyweight_kg"))
    if bodyweight is not None and not (25.0 <= bodyweight <= 250.0):
        warnings.append(
            f"{session_id}: bodyweight {bodyweight:g}kg is outside 25-250; ignored"
        )
        bodyweight = None

    return Session(
        id=session_id,
        day=day,
        distance_m=distance,
        time_s=time_s,
        split_s=split_s,
        tag=tag,
        stroke_rate=stroke_rate,
        rep_distance_m=rep_distance,
        effective_distance_m=effective_distance,
        interval_ambiguous=interval_ambiguous,
        rate_mismatch=rate_mismatch,
        rpe=rpe,
        rpe_mismatch=rpe_mismatch,
        bodyweight_kg=bodyweight,
    )


# --------------------------------------------------------------------------------------
# Anchor selection
# --------------------------------------------------------------------------------------

@dataclass(frozen=True)
class Anchor:
    tag: str
    split_s: float
    effective_distance_m: float
    day: date
    session_ids: list[str]
    method: str
    interval_ambiguous: bool
    rate_mismatch: bool
    rpe: float | None = None
    rpe_mismatch: bool = False
    rpe_coverage: float = 1.0   # share of the anchor's duration carrying a usable RPE

    @property
    def tier(self) -> Tier:
        return TIERS[self.tag]


def _weighted_median(pairs: Sequence[tuple[float, float]]) -> float:
    """Weighted median of (value, weight) pairs."""
    if not pairs:
        raise ValueError("cannot take the median of an empty sequence")
    ordered = sorted(pairs, key=lambda pair: pair[0])
    total = sum(weight for _, weight in ordered)
    if total <= 0:
        return ordered[len(ordered) // 2][0]
    running = 0.0
    for value, weight in ordered:
        running += weight
        if running >= total / 2.0:
            return value
    return ordered[-1][0]


def _select_anchor(
    sessions: Sequence[Session],
    target_distance: float,
    config: EngineConfig,
) -> Anchor | None:
    """Pick the best available anchor, walking tiers in priority order.

    Maximal tiers use the single session whose effort distance is closest to the target,
    because Paul's Law error grows with the distance ratio. v1.0 specified "longest",
    which maximises that ratio — exactly the wrong direction.

    Submaximal tiers aggregate: one steady-state row is a noisy estimate of a
    physiological ceiling, so we take the duration-weighted median across the window.
    """
    if not sessions:
        return None

    for tag in sorted(TIERS, key=lambda name: TIERS[name].rank):
        candidates = [s for s in sessions if s.tag == tag]
        if not candidates:
            continue

        if tag in MAXIMAL_TIERS:
            def closeness(session: Session) -> tuple[float, int]:
                ratio = target_distance / max(session.effective_distance_m, 1e-9)
                return (abs(math.log2(ratio)), -session.day.toordinal())

            best = min(candidates, key=closeness)
            return Anchor(
                tag=tag,
                split_s=best.split_s,
                effective_distance_m=best.effective_distance_m,
                day=best.day,
                session_ids=[best.id],
                method="closest_distance",
                interval_ambiguous=best.interval_ambiguous,
                rate_mismatch=best.rate_mismatch,
                rpe=best.rpe,
                rpe_mismatch=best.rpe_mismatch,
            )

        if config.submaximal_anchor_method == "single_session":
            best = max(candidates, key=lambda s: (s.distance_m, s.day.toordinal()))
            return Anchor(
                tag=tag,
                split_s=best.split_s,
                effective_distance_m=best.effective_distance_m,
                day=best.day,
                session_ids=[best.id],
                method="longest_single_session",
                interval_ambiguous=best.interval_ambiguous,
                rate_mismatch=best.rate_mismatch,
                rpe=best.rpe,
                rpe_mismatch=best.rpe_mismatch,
            )

        split = _weighted_median([(s.split_s, s.duration_minutes) for s in candidates])
        distance = _weighted_median(
            [(s.effective_distance_m, s.duration_minutes) for s in candidates]
        )
        tier_rpe, tier_coverage, tier_mismatch = _tier_rpe(candidates)
        return Anchor(
            tag=tag,
            split_s=split,
            effective_distance_m=distance,
            day=max(s.day for s in candidates),
            session_ids=[s.id for s in candidates],
            method="duration_weighted_median",
            interval_ambiguous=any(s.interval_ambiguous for s in candidates),
            rate_mismatch=sum(s.rate_mismatch for s in candidates) > len(candidates) / 2,
            # Tier-typical effort from consistently-rated sessions only, with coverage so
            # a handful of ratings can't steer the whole tier. See `_tier_rpe`.
            rpe=tier_rpe,
            rpe_mismatch=tier_mismatch,
            rpe_coverage=tier_coverage,
        )

    return None


# --------------------------------------------------------------------------------------
# Core maths
# --------------------------------------------------------------------------------------

def _normalise_to_reference(
    split_s: float,
    effective_distance_m: float,
    tier: Tier,
    config: EngineConfig,
) -> tuple[float, float, float]:
    """Invert the session model to recover the athlete's maximal 2000m split.

        observed = S2k + w_T * 5 * log2(d / ref_T) + g_T
        S2k      = observed - w_T * 5 * log2(d / ref_T) - g_T

    Returns (S2k, paul_adjustment, intensity_offset) where the two adjustments are the
    signed contributions actually applied, so the UI can show the arithmetic.

    Both correction terms are measured from the tier's own reference distance. That is
    what stops the distance discount being counted twice — the failure mode in v1.0, and
    (at smaller magnitude) in v1.1's middle tiers.
    """
    if effective_distance_m <= 0:
        raise ValueError("effective distance must be positive")
    ratio = effective_distance_m / tier.ref_distance_m
    paul_adjustment = -tier.paul_weight * config.paul_constant * math.log2(ratio)
    intensity_offset = -tier.offset
    return split_s + paul_adjustment + intensity_offset, paul_adjustment, intensity_offset


def _interpolate(knots: Sequence[tuple[float, float]], x: float) -> float:
    """Piecewise-linear interpolation with flat extrapolation beyond the end knots."""
    points = sorted(knots)
    if x <= points[0][0]:
        return points[0][1]
    if x >= points[-1][0]:
        return points[-1][1]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if x0 <= x <= x1:
            if x1 == x0:
                return y1
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return points[-1][1]


def _rolling_load(sessions: Sequence[Session]) -> float:
    """TRIMP-lite: duration in minutes times the tier's intensity multiplier."""
    return sum(s.duration_minutes * s.tier.load for s in sessions)


def _rpe_offset_correction(rpe: float | None, tier: Tier, rpe_mismatch: bool,
                           config: EngineConfig) -> float:
    """Seconds to ADD to the recovered S2k, given how hard the anchor felt.

    Felt harder than the zone normally does -> the athlete was nearer their ceiling than
    the tag assumes -> the true gap to max is smaller -> S2k is slower than the raw
    inversion suggests -> positive correction. Felt easier -> negative.

    Returns 0.0 when RPE is absent, and also when RPE contradicts the tag outright: a
    contradiction is evidence the TAG is wrong, and the right response is to flag it and
    cut confidence, not to bend the pace by an amount the tag can't justify.

    Also 0.0 for AN. An all-out test is the measurement itself — the stopwatch already
    says what the athlete can do at that distance. RPE on an AN piece can only tell us
    the tag was wrong (handled by the contradiction check), never that the athlete is
    faster or slower than the time they just rowed.
    """
    if rpe is None or rpe_mismatch or tier.name == "AN":
        return 0.0
    raw = config.rpe_sensitivity * (rpe - tier.rpe_mid)
    return max(-config.rpe_max_correction, min(config.rpe_max_correction, raw))


def _tier_rpe(candidates: Sequence[Session]) -> tuple[float | None, float, bool]:
    """Aggregate RPE for a submaximal tier: (median_rpe, coverage, majority_mismatch).

    Only sessions whose RPE is consistent with their tag contribute to the median. A
    contradicted rating is evidence of a mis-tag, not of effort within the zone, and
    letting it into the median let one mis-tagged row shift the whole prediction.

    `coverage` is the share of the tier's duration that carried a usable rating. The
    correction is scaled by it, for the same reason the volume modifier is scaled by
    session count: one rated row out of nineteen is not evidence about the other eighteen.
    """
    total = sum(s.duration_minutes for s in candidates)
    rated = [(s.rpe, s.duration_minutes) for s in candidates if s.rpe is not None]
    usable = [(s.rpe, s.duration_minutes) for s in candidates
              if s.rpe is not None and not s.rpe_mismatch]
    majority_mismatch = sum(s.rpe_mismatch for s in candidates) > len(candidates) / 2
    if not rated or total <= 0:
        return None, 0.0, majority_mismatch
    if not usable:
        # Every rating contradicts the tag. Report what was rated, so the UI can tell
        # the user what looked wrong, but with zero coverage it can never move the pace.
        return _weighted_median(rated), 0.0, majority_mismatch
    coverage = sum(w for _, w in usable) / total
    return _weighted_median(usable), coverage, majority_mismatch


def weight_adjustment_factor(weight_kg: float, config: EngineConfig = None) -> float:
    """Concept2's published weight factor: Wf = (lbs / 270) ^ 0.222.

    Corrected time = actual time x Wf. Below 270lb, Wf < 1 and the corrected time is
    faster, crediting a lighter rower for moving the same boat with less mass.
    Source: https://www.concept2.com/training/weight-adjustment-calculator
    """
    config = config or DEFAULT_CONFIG
    if weight_kg is None or weight_kg <= 0:
        raise ValueError("weight must be positive")
    pounds = weight_kg * 2.2046226218
    return (pounds / config.weight_adjust_reference_lb) ** config.weight_adjust_exponent


def _age_penalty_fraction(age: float, reference_age: float,
                          curve: Sequence[tuple[float, float]]) -> float:
    """Fractional slowdown in expected 2k time relative to the reference age.

    There is no official Concept2 age-grading formula. From the reference age up, the
    curve is FITTED from the Concept2 rankings medians (`prior_age_curve`): linear
    between knots starting from (reference age, 0), and past the last knot at the last
    segment's slope.

    Below the reference age it is still the SEED rule, because the rankings can't fit it:
    ranked juniors are a strongly selected group whose median is as fast as the 19-29
    median, which says nothing about a typical 16-year-old.

        under 18   +2.5% per year below 18, on top of the 18-year-old value
        18 -> ref  linear from +6% at 18 to 0% at the reference age
    """
    if age < reference_age:
        if age >= 18.0:
            span = max(reference_age - 18.0, 1e-9)
            return 0.06 * (reference_age - age) / span
        return 0.06 + 0.025 * (18.0 - age)

    points = [(reference_age, 0.0)] + [tuple(knot) for knot in curve]
    if len(points) < 2:
        return 0.0
    for (a0, f0), (a1, f1) in zip(points, points[1:]):
        if age <= a1:
            return f0 + (f1 - f0) * (age - a0) / max(a1 - a0, 1e-9)
    (a0, f0), (a1, f1) = points[-2], points[-1]
    return f1 + (f1 - f0) * (age - a1) / max(a1 - a0, 1e-9)


def age_performance_factor(age: float | None, config: EngineConfig = None) -> float:
    """Multiplier on expected 2k time relative to the reference age. 1.0 when unknown."""
    config = config or DEFAULT_CONFIG
    if age is None:
        return 1.0
    return 1.0 + _age_penalty_fraction(age, config.prior_reference_age,
                                       config.prior_age_curve)


def _population_prior_2k(athlete: Athlete, config: EngineConfig) -> tuple[float, list[str]]:
    """A population estimate of 2k time in seconds, from demographics alone.

    Used ONLY when there is no training history. This is where age, sex and weight
    legitimately belong: with no rowing data, the population is the only evidence there
    is. Returns (seconds, notes) where notes explain each adjustment for the UI.
    """
    notes: list[str] = []

    if athlete.sex == "male":
        base, ref_kg = config.prior_male_2k_seconds, config.prior_male_reference_kg
        notes.append(f"male population baseline {format_seconds(base)} "
                     "(Concept2 rankings median, ages 19-29)")
    elif athlete.sex == "female":
        base, ref_kg = config.prior_female_2k_seconds, config.prior_female_reference_kg
        notes.append(f"female population baseline {format_seconds(base)} "
                     "(Concept2 rankings median, ages 19-29)")
    else:
        base = (config.prior_male_2k_seconds + config.prior_female_2k_seconds) / 2.0
        ref_kg = (config.prior_male_reference_kg + config.prior_female_reference_kg) / 2.0
        notes.append(f"sex-neutral population baseline {format_seconds(base)} "
                     "(wider uncertainty)")

    # Weight: raw performance scales as weight ^ -0.222 (Concept2). This is the use the
    # formula was designed for — comparing different people — so it applies at full
    # strength here, unlike the weight-trend term in the prediction layer.
    if athlete.weight_kg is not None:
        scale = (ref_kg / athlete.weight_kg) ** config.weight_adjust_exponent
        base *= scale
        notes.append(f"weight {athlete.weight_kg:g}kg vs reference {ref_kg:g}kg "
                     f"({(scale - 1) * 100:+.1f}%)")

    if athlete.age is not None:
        factor = age_performance_factor(athlete.age, config)
        base *= factor
        notes.append(f"age {athlete.age:g} ({(factor - 1) * 100:+.1f}%)")

    return base, notes


def _weight_trend_correction(window: Sequence[Session], anchor: "Anchor",
                             base_split: float, config: EngineConfig
                             ) -> tuple[float, float | None, float | None]:
    """Seconds per 500m to add to the prediction for bodyweight change since the anchor.

    Returns (correction_seconds_per_500, anchor_weight_kg, current_weight_kg).

    Both ends of the comparison come from DATED session weigh-ins: the one closest to
    the anchor date and the most recent. The undated profile weight is deliberately not
    used here — it may have been typed at signup months ago, and comparing it with a
    weigh-in logged last week manufactures a "trend" out of two different scales.
    Scaled by `weight_trend_sensitivity`, which defaults to 0 — see EngineConfig.
    """
    weighed = sorted((s for s in window if s.bodyweight_kg is not None),
                     key=lambda s: s.day)
    if not weighed:
        return 0.0, None, None

    anchor_weight = min(weighed, key=lambda s: abs((s.day - anchor.day).days)).bodyweight_kg
    current_weight = weighed[-1].bodyweight_kg

    if (config.weight_trend_sensitivity == 0.0
            or abs(current_weight - anchor_weight) < config.weight_trend_min_kg):
        return 0.0, anchor_weight, current_weight

    # Raw time ~ weight^-0.222, so the predicted maximal split at the target scales by
    # (current/anchor)^-0.222. Applied to the projected split — the quantity being
    # predicted — not to the anchor's training split, which can be 10% slower.
    ratio = (current_weight / anchor_weight) ** (-config.weight_adjust_exponent)
    correction = base_split * (ratio - 1.0) * config.weight_trend_sensitivity
    return correction, anchor_weight, current_weight


def _interpretation(split_s: float, target: float, athlete: Athlete,
                    config: EngineConfig) -> dict[str, Any]:
    """Comparable scores DERIVED from the prediction. Never fed back into it."""
    total = split_s * target / 500.0
    block: dict[str, Any] = {
        "weight_adjusted": None,
        "age_graded": None,
        "notes": [],
    }

    if athlete.weight_kg is not None:
        factor = weight_adjustment_factor(athlete.weight_kg, config)
        adjusted = total * factor
        block["weight_adjusted"] = {
            "factor": round(factor, 4),
            "total_time_seconds": round(adjusted, 2),
            "total_time_formatted": format_seconds(adjusted),
            "split_formatted": format_seconds(adjusted / target * 500.0),
            "method": "Concept2: Wf = (lbs / 270) ^ 0.222",
        }

    if athlete.age is not None:
        factor = age_performance_factor(athlete.age, config)
        graded = total / factor
        block["age_graded"] = {
            "factor": round(factor, 4),
            "reference_age": config.prior_reference_age,
            "total_time_seconds": round(graded, 2),
            "total_time_formatted": format_seconds(graded),
            "split_formatted": format_seconds(graded / target * 500.0),
            "method": "fitted to Concept2 rankings medians (2025-26), "
                      "not an official standard",
        }
        block["notes"].append(
            "Age grading follows the median ranked 2k at each age, from rowers who chose "
            "to log a ranked result. Treat it as indicative, not an official standard."
        )

    return block


# --------------------------------------------------------------------------------------
# Diagnostics
# --------------------------------------------------------------------------------------

def diagnose_history(
    history: Iterable[Mapping[str, Any]],
    as_of: date | None = None,
    config: EngineConfig | None = None,
) -> dict[str, Any]:
    """Compute an independent 2000m-equivalent from each tier present.

    This is both a confidence input and the calibration harness: if the tier constants
    are correctly tuned for a cohort, every tier should imply roughly the same S2k. A
    persistent bias in one tier's estimate is a direct instruction to adjust that tier's
    offset. See SPEC.md §6.2.
    """
    config = config or DEFAULT_CONFIG
    as_of = as_of or date.today()
    warnings: list[str] = []
    sessions = [
        s for s in (
            _normalise_session(raw, i, config, warnings)
            for i, raw in enumerate(history)
        )
        if s is not None and as_of - timedelta(days=config.window_days) <= s.day <= as_of
    ]

    estimates: dict[str, float] = {}
    for tag in TIERS:
        candidates = [s for s in sessions if s.tag == tag]
        if not candidates:
            continue
        tier = TIERS[tag]
        if tag in MAXIMAL_TIERS:
            # Best effort represents the tier; a slow rep set is not evidence of a ceiling.
            representative = min(candidates, key=lambda s: s.split_s)
            split, distance = representative.split_s, representative.effective_distance_m
            rpe, rpe_mismatch = representative.rpe, representative.rpe_mismatch
        else:
            split = _weighted_median([(s.split_s, s.duration_minutes) for s in candidates])
            distance = _weighted_median(
                [(s.effective_distance_m, s.duration_minutes) for s in candidates]
            )
            rpe, coverage, rpe_mismatch = _tier_rpe(candidates)
        if tag in MAXIMAL_TIERS:
            coverage = 1.0
        reference, _, _ = _normalise_to_reference(split, distance, tier, config)
        # Same RPE correction as the prediction path, so the agreement check measures the
        # model the user actually gets rather than a stripped-down version of it.
        reference += _rpe_offset_correction(rpe, tier, rpe_mismatch, config) * coverage
        estimates[tag] = round(reference, 2)

    spread = max(estimates.values()) - min(estimates.values()) if len(estimates) > 1 else 0.0
    return {
        "two_k_equivalent_by_tier": estimates,
        "two_k_equivalent_formatted": {
            tag: format_seconds(value) for tag, value in estimates.items()
        },
        "spread_seconds": round(spread, 2),
        "tiers_represented": len(estimates),
        "warnings": warnings,
    }


# --------------------------------------------------------------------------------------
# Confidence
# --------------------------------------------------------------------------------------

def _score_confidence(
    anchor: Anchor,
    sessions: Sequence[Session],
    target_distance: float,
    spread_s: float,
    as_of: date,
    config: EngineConfig,
    fatigue_excess: float | None = None,
) -> tuple[int, str, list[dict[str, Any]], list[str]]:
    factors: list[dict[str, Any]] = []
    recommendations: list[str] = []
    days_ago = (as_of - anchor.day).days

    if anchor.tag == "AN" and days_ago <= config.recent_anchor_days:
        score, label = 90, "Recent all-out test piece"
    elif anchor.tag == "TR" and days_ago <= config.recent_anchor_days:
        score, label = 80, "Recent race-pace work"
    elif anchor.tag in MAXIMAL_TIERS:
        score, label = 65, f"{anchor.tag} anchor, {days_ago} days old"
    elif anchor.tag == "AT":
        score, label = 60, "Threshold work only"
    elif anchor.tag == "UT1":
        score, label = 42, "Low-intensity anchor only"
    else:
        score, label = 35, "Steady-state volume only"
    factors.append({"label": label, "delta": score})

    if anchor.tag not in MAXIMAL_TIERS or days_ago > config.recent_anchor_days:
        recommendations.append(
            "Log an all-out test piece (AN) or a hard race-pace effort (TR) in the next "
            "two weeks to raise confidence."
        )

    ratio_log2 = abs(math.log2(target_distance / max(anchor.effective_distance_m, 1e-9)))
    if ratio_log2 > config.ratio_severe_log2:
        factors.append({
            "label": f"Anchor distance is far from {int(target_distance)}m "
                     f"({ratio_log2:.1f} doublings apart)",
            "delta": -25,
        })
        score -= 25
        recommendations.append(
            f"Paul's Law is unreliable across this distance gap. A piece nearer "
            f"{int(target_distance)}m would sharply improve this prediction."
        )
    elif ratio_log2 > config.ratio_warn_log2:
        factors.append({
            "label": f"Anchor distance differs from target by {ratio_log2:.1f} doublings",
            "delta": -15,
        })
        score -= 15

    count = len(sessions)
    if count < config.min_sessions_minimum:
        factors.append({"label": f"Only {count} session(s) in the window", "delta": -20})
        score -= 20
    elif count < config.min_sessions_comfortable:
        factors.append({"label": f"Only {count} sessions in the window", "delta": -12})
        score -= 12

    last_session_days = min((as_of - s.day).days for s in sessions)
    if last_session_days > config.stale_history_days:
        factors.append({
            "label": f"No sessions logged in {last_session_days} days",
            "delta": -10,
        })
        score -= 10
        recommendations.append("Log recent sessions — this history has gone stale.")

    if anchor.rate_mismatch:
        tier = anchor.tier
        factors.append({
            "label": f"Anchor stroke rate is outside the usual {anchor.tag} range "
                     f"({tier.rate_lo:.0f}-{tier.rate_hi:.0f} spm)",
            "delta": -10,
        })
        score -= 10
        recommendations.append(
            f"Check the intensity tag on the anchor session — the stroke rate does not "
            f"look like {anchor.tag}."
        )

    if spread_s > config.tier_spread_tolerance_s:
        factors.append({
            "label": f"Intensity zones disagree by {spread_s:.1f}s per 500m",
            "delta": -10,
        })
        score -= 10
        recommendations.append(
            "Your zones imply different fitness levels. Reviewing how sessions are tagged "
            "would tighten every prediction."
        )

    if anchor.interval_ambiguous:
        factors.append({
            "label": "Anchor may be an interval session with no rep distance recorded",
            "delta": -15,
        })
        score -= 15
        recommendations.append(
            "Record the rep distance on interval sessions — it is the single biggest "
            "accuracy win available."
        )

    if anchor.rpe_mismatch:
        tier = anchor.tier
        reported = "" if anchor.rpe is None else f" (RPE {anchor.rpe:.1f})"
        factors.append({
            "label": f"Anchor effort{reported} doesn't match a typical "
                     f"{anchor.tag} session (RPE {tier.rpe_lo:g}-{tier.rpe_hi:g})",
            "delta": -10,
        })
        score -= 10
        recommendations.append(
            f"The effort you reported doesn't look like {anchor.tag}. Check the zone tag "
            "on that session."
        )

    if fatigue_excess is not None and fatigue_excess > config.fatigue_rpe_excess:
        factors.append({
            "label": f"Recent sessions have felt harder than usual "
                     f"(+{fatigue_excess:.1f} RPE)",
            "delta": -8,
        })
        score -= 8
        recommendations.append(
            "Your recent sessions are feeling harder than their zones normally do. If "
            "you're carrying fatigue, a test now would likely come in slower than this "
            "prediction — a few easier days first would give a truer result."
        )

    score = max(5, min(95, int(round(score))))
    if score >= config.high_threshold:
        band = "High"
    elif score >= config.medium_threshold:
        band = "Medium"
    else:
        band = "Low"
    return score, band, factors, recommendations


def _dedupe_raw(raw_sessions: list[Any], warnings: list[str],
                flags: list[str]) -> list[Any]:
    """Drop repeated session ids, keeping the LAST occurrence.

    A retried upload or a re-synced record would otherwise be counted twice: double the
    training load, double weight in every median. The last copy wins because an edited
    session (a corrected OCR read, say) is the later write. Rows without an explicit id
    can't be matched and are kept.
    """
    last_index: dict[str, int] = {}
    for index, raw in enumerate(raw_sessions):
        if isinstance(raw, Mapping):
            session_id = _pluck(raw, "id")
            if session_id is not None:
                last_index[str(session_id)] = index

    kept: list[Any] = []
    dropped = 0
    for index, raw in enumerate(raw_sessions):
        if isinstance(raw, Mapping):
            session_id = _pluck(raw, "id")
            if session_id is not None and last_index[str(session_id)] != index:
                dropped += 1
                continue
        kept.append(raw)

    if dropped:
        warnings.append(f"{dropped} duplicate session(s) by id were ignored; "
                        "kept the latest copy of each")
        flags.append("duplicate_sessions_removed")
    return kept


# --------------------------------------------------------------------------------------
# Public entry point
# --------------------------------------------------------------------------------------

def predict_test_piece(
    history: Iterable[Mapping[str, Any]],
    target_distance: float,
    as_of: date | str | datetime | None = None,
    config: EngineConfig | None = None,
    athlete: Mapping[str, Any] | Athlete | None = None,
) -> dict[str, Any]:
    """Predict a test-piece split and total time from session-summary history.

    Args:
        history: iterable of session dicts (see SPEC.md §3).
        target_distance: metres, positive.
        as_of: evaluation date; defaults to today. Pass explicitly in tests.
        config: EngineConfig override.
        athlete: optional profile {age, sex, weight_kg}. Drives the interpretation
            layer and the cold-start prior. Does NOT alter an anchored prediction.

    Returns:
        A JSON-serialisable dict (see SPEC.md §6). Never raises on bad input data — every
        failure mode surfaces as a null prediction (or a labelled population estimate)
        plus warnings.
    """
    config = config or DEFAULT_CONFIG
    warnings: list[str] = []
    flags: list[str] = []
    profile = _normalise_athlete(athlete, warnings)

    resolved_as_of = parse_date(as_of) if as_of is not None else date.today()
    if resolved_as_of is None:
        warnings.append("Unparseable as_of date; falling back to today")
        resolved_as_of = date.today()

    target = _to_float(target_distance)
    if target is None or target <= 0:
        return _empty_result(
            target_distance, config,
            warnings + [f"Target distance must be a positive number, got {target_distance!r}"],
            ["invalid_target_distance"],
        )
    if target < 100:
        warnings.append(
            f"Target of {target:.0f}m is below the range Paul's Law was derived over; "
            "treat the result as indicative only"
        )
        flags.append("target_below_supported_range")

    if history is None:
        history = []
    raw_sessions = _dedupe_raw(list(history), warnings, flags)

    parsed = [
        session for session in (
            _normalise_session(raw, index, config, warnings)
            for index, raw in enumerate(raw_sessions)
        )
        if session is not None
    ]

    future = [s for s in parsed if s.day > resolved_as_of]
    if future:
        warnings.append(
            f"{len(future)} session(s) dated after {resolved_as_of.isoformat()} were ignored"
        )
        flags.append("future_dated_session")
        parsed = [s for s in parsed if s.day <= resolved_as_of]

    cutoff = resolved_as_of - timedelta(days=config.window_days)
    window = [s for s in parsed if s.day >= cutoff]

    # --- Cold start and near-cold start -------------------------------------------------
    if not window:
        if parsed:
            newest = max(s.day for s in parsed)
            stale_days = (resolved_as_of - newest).days
            warnings.append(
                f"No sessions inside the {config.window_days}-day window; the most recent "
                f"is {stale_days} days old"
            )
            flags.append("history_outside_window")
        else:
            warnings.append("No usable sessions found")
            flags.append("cold_start")
        # With a profile and NO rowing history at all, offer a clearly-labelled population
        # estimate rather than a blank. If the athlete has history that's merely older
        # than the window, do not: their own stale result is better evidence than a seed
        # number, and showing "7:20 Population Estimate" to someone who rowed 6:30 last
        # month is wrong in a way users notice.
        if not profile.is_empty and not parsed:
            return _population_estimate_result(target, profile, config, warnings, flags,
                                               resolved_as_of)
        return _empty_result(target, config, warnings, flags)

    anchor = _select_anchor(window, target, config)
    if anchor is None:  # defensive: window is non-empty and every session carries a valid tag
        warnings.append("No session in the window qualified as an anchor")
        flags.append("no_anchor")
        return _empty_result(target, config, warnings, flags)

    diagnostics = diagnose_history(raw_sessions, resolved_as_of, config)
    spread = float(diagnostics["spread_seconds"])

    # --- Step 3: recover S2k from the anchor, then project to the target ----------------
    tier = anchor.tier
    if config.legacy_v1_formula:
        # Original v1.0 single-step formula, retained only so its divergence is measurable.
        reference_split = float("nan")
        paul_adjustment = config.paul_constant * math.log2(
            target / max(anchor.effective_distance_m, 1e-9)
        )
        intensity_offset = -tier.offset
        base_split = anchor.split_s + paul_adjustment + intensity_offset
        projection = 0.0
        flags.append("legacy_v1_formula_enabled")
    else:
        reference_split, paul_adjustment, intensity_offset = _normalise_to_reference(
            anchor.split_s, anchor.effective_distance_m, tier, config
        )
        # Perceived effort refines where in its tier the anchor actually sat.
        rpe_correction = _rpe_offset_correction(anchor.rpe, tier, anchor.rpe_mismatch,
                                                config) * anchor.rpe_coverage
        reference_split += rpe_correction
        # A test piece is a maximal effort by definition, so the projection runs at full
        # Paul weight regardless of what tier the anchor came from.
        projection = config.paul_constant * math.log2(target / config.reference_distance_m)
        base_split = reference_split + projection
    if config.legacy_v1_formula:
        rpe_correction = 0.0

    # --- Bodyweight trend (off by default; see EngineConfig.weight_trend_sensitivity) ---
    weight_correction, anchor_weight, current_weight = _weight_trend_correction(
        window, anchor, base_split, config
    )
    if (anchor_weight is not None and current_weight is not None
            and abs(current_weight - anchor_weight) >= config.weight_trend_min_kg):
        if weight_correction == 0.0:
            flags.append("weight_change_not_applied")
        else:
            flags.append("weight_trend_applied")
    base_split += weight_correction

    # --- Fatigue read from RPE (confidence and advice only, never pace) -----------------
    fatigue_cutoff = resolved_as_of - timedelta(days=config.fatigue_window_days)
    recent_rated = [s for s in window
                    if s.day >= fatigue_cutoff and s.rpe is not None and not s.rpe_mismatch]
    fatigue_excess = (sum(s.rpe_deviation for s in recent_rated) / len(recent_rated)
                      if len(recent_rated) >= 2 else None)
    if fatigue_excess is not None and fatigue_excess > config.fatigue_rpe_excess:
        flags.append("elevated_recent_effort")
    if anchor.rpe_mismatch:
        flags.append("anchor_tag_rpe_mismatch")

    # --- Step 4: volume modifier ---------------------------------------------------------
    #
    # Damped by how much history the load figure is built on. With two logged sessions we
    # do not know the athlete is detrained — we know they have logged twice. Charging a
    # sparse logger the full +3s detraining penalty punishes logging behaviour rather than
    # fitness, and it is exactly the user who has just logged a single 2k test who would
    # be told their 2k is 11 seconds slower than the one they rowed yesterday.
    load = _rolling_load(window)
    raw_modifier = _interpolate(config.load_knots, load)
    load_confidence = min(1.0, len(window) / config.min_sessions_comfortable)
    volume_modifier = raw_modifier * load_confidence
    if load_confidence < 1.0:
        flags.append("load_estimate_damped")
    modelled_split = base_split + volume_modifier

    # --- Clamps --------------------------------------------------------------------------
    floor = config.floor_split_at_reference + config.paul_constant * math.log2(
        target / config.reference_distance_m
    )
    final_split = modelled_split
    if modelled_split < floor:
        final_split = floor
        flags.append("clamped_to_physiological_floor")
        warnings.append(
            "The model produced a split faster than world-record pace and has been clamped. "
            "This usually means a mis-tagged session or a mis-entered distance."
        )
    elif modelled_split > config.ceiling_split:
        final_split = config.ceiling_split
        flags.append("clamped_to_ceiling")
        warnings.append("The model produced an implausibly slow split and has been clamped.")

    if anchor.interval_ambiguous:
        flags.append("interval_structure_ambiguous")
    if anchor.rate_mismatch:
        flags.append("anchor_tag_rate_mismatch")
    if spread > config.tier_spread_tolerance_s:
        flags.append("tier_disagreement")

    score, band, factors, recommendations = _score_confidence(
        anchor, window, target, spread, resolved_as_of, config, fatigue_excess
    )

    # A clamped result means the inputs produced a physiologically impossible number —
    # almost always a typo or a mis-tag. Showing "5:28.0, Medium confidence" invites the
    # user to believe a world record. Cap it at Low and say why.
    if final_split != modelled_split:
        capped = min(score, config.medium_threshold - 1)
        if capped < score:
            factors.append({"label": "Prediction hit a physiological limit — check the "
                                     "anchor session for a typo or wrong zone",
                            "delta": capped - score})
            score = capped
        band = "Low"
        recommendations.append(
            "One of your sessions produced an impossible result. Check the distance, time "
            "and zone on your most recent hard session."
        )

    total_time = final_split * target / 500.0
    rated_count = sum(1 for s in window if s.rpe is not None)

    return {
        "schema_version": SCHEMA_VERSION,
        "generated_for_date": resolved_as_of.isoformat(),
        "target_distance_m": round(target, 1),
        "predicted_split_seconds": round(final_split, 2),
        "predicted_split_formatted": format_seconds(final_split),
        "predicted_total_time_seconds": round(total_time, 2),
        "predicted_total_time_formatted": format_seconds(total_time),
        "confidence_score": band,
        "confidence_numeric": score,
        "confidence_factors": factors,
        "anchor": {
            "tier": anchor.tag,
            "session_ids": anchor.session_ids,
            "date": anchor.day.isoformat(),
            "days_ago": (resolved_as_of - anchor.day).days,
            "split_seconds": round(anchor.split_s, 2),
            "split_formatted": format_seconds(anchor.split_s),
            "effective_distance_m": round(anchor.effective_distance_m, 1),
            "method": anchor.method,
            "rpe": None if anchor.rpe is None else round(anchor.rpe, 1),
        },
        "load": {
            "trimp_lite": round(load, 1),
            "session_count": len(window),
            "window_days": config.window_days,
            "raw_modifier_seconds": round(raw_modifier, 2),
            "load_confidence": round(load_confidence, 2),
            "modifier_seconds": round(volume_modifier, 2),
        },
        # Reads top to bottom as the arithmetic: anchor + paul + offset + rpe = 2k
        # equivalent; then + projection + weight + volume + clamp = predicted split.
        "components": {
            "anchor_split": round(anchor.split_s, 2),
            "paul_adjustment": round(paul_adjustment, 2),
            "intensity_offset": round(intensity_offset, 2),
            "rpe_correction": round(rpe_correction, 2),
            "two_k_equivalent": (
                None if math.isnan(reference_split) else round(reference_split, 2)
            ),
            "projection_to_target": round(projection, 2),
            "weight_trend_correction": round(weight_correction, 2),
            "volume_modifier": round(volume_modifier, 2),
            "clamp_adjustment": round(final_split - modelled_split, 2),
        },
        "effort": {
            "sessions_with_rpe": rated_count,
            "anchor_rpe": None if anchor.rpe is None else round(anchor.rpe, 1),
            "recent_rpe_excess": (None if fatigue_excess is None
                                  else round(fatigue_excess, 2)),
        },
        "athlete": {
            "age": profile.age,
            "sex": profile.sex,
            "weight_kg": profile.weight_kg,
            "bodyweight_at_anchor_kg": anchor_weight,
            "used_in_prediction": weight_correction != 0.0,
        },
        "interpretation": _interpretation(final_split, target, profile, config),
        "diagnostics": diagnostics,
        "flags": flags,
        "warnings": warnings,
        "recommendations": recommendations,
    }


def _population_estimate_result(
    target: float,
    profile: Athlete,
    config: EngineConfig,
    warnings: list[str],
    flags: list[str],
    as_of: date,
) -> dict[str, Any]:
    """A demographic estimate for a user with no usable history.

    Deliberately shaped so a UI cannot mistake it for a prediction: its own confidence
    band, a null anchor, a `population_estimate` flag, and an explicit basis list.
    """
    two_k_seconds, notes = _population_prior_2k(profile, config)
    s2k = two_k_seconds / 4.0
    projection = config.paul_constant * math.log2(target / config.reference_distance_m)
    split = min(max(s2k + projection, config.floor_split_at_reference + projection),
                config.ceiling_split)
    total = split * target / 500.0
    flags = flags + ["population_estimate", "prior_from_concept2_rankings"]
    if profile.sex is None:
        flags.append("sex_neutral_prior")

    return {
        "schema_version": SCHEMA_VERSION,
        "generated_for_date": as_of.isoformat(),
        "target_distance_m": round(target, 1),
        "predicted_split_seconds": round(split, 2),
        "predicted_split_formatted": format_seconds(split),
        "predicted_total_time_seconds": round(total, 2),
        "predicted_total_time_formatted": format_seconds(total),
        "confidence_score": "Population Estimate",
        "confidence_numeric": config.prior_confidence_numeric,
        "confidence_factors": [{
            "label": "No training data — estimate is based on people like you, not on you",
            "delta": config.prior_confidence_numeric,
        }],
        "anchor": None,
        "load": {"trimp_lite": 0.0, "session_count": 0,
                 "window_days": config.window_days, "raw_modifier_seconds": 0.0,
                 "load_confidence": 0.0, "modifier_seconds": 0.0},
        "components": {
            "population_2k_seconds": round(two_k_seconds, 2),
            "two_k_equivalent": round(s2k, 2),
            "projection_to_target": round(projection, 2),
        },
        "estimate_basis": notes,
        "effort": {"sessions_with_rpe": 0, "anchor_rpe": None, "recent_rpe_excess": None},
        "athlete": {"age": profile.age, "sex": profile.sex, "weight_kg": profile.weight_kg,
                    "bodyweight_at_anchor_kg": None, "used_in_prediction": True},
        "interpretation": _interpretation(split, target, profile, config),
        "diagnostics": {"two_k_equivalent_by_tier": {}, "spread_seconds": 0.0,
                        "tiers_represented": 0, "warnings": []},
        "flags": flags,
        "warnings": warnings,
        "recommendations": [
            "This is a starting estimate from population data. Log a few sessions — "
            "ideally one hard effort — and it will be replaced by a prediction built "
            "from your own rowing."
        ],
    }


def _empty_result(
    target_distance: Any,
    config: EngineConfig,
    warnings: list[str],
    flags: list[str],
) -> dict[str, Any]:
    """The honest no-prediction response. Never guess a number to fill the UI."""
    target = _to_float(target_distance)
    return {
        "schema_version": SCHEMA_VERSION,
        "target_distance_m": round(target, 1) if target and target > 0 else None,
        "predicted_split_seconds": None,
        "predicted_split_formatted": None,
        "predicted_total_time_seconds": None,
        "predicted_total_time_formatted": None,
        "confidence_score": "Insufficient Data",
        "confidence_numeric": 0,
        "confidence_factors": [],
        "anchor": None,
        "load": {"trimp_lite": 0.0, "session_count": 0,
                 "window_days": config.window_days, "raw_modifier_seconds": 0.0,
                 "load_confidence": 0.0, "modifier_seconds": 0.0},
        "components": {},
        "effort": {"sessions_with_rpe": 0, "anchor_rpe": None, "recent_rpe_excess": None},
        "athlete": None,
        "interpretation": None,
        "diagnostics": {"two_k_equivalent_by_tier": {}, "spread_seconds": 0.0,
                        "tiers_represented": 0, "warnings": []},
        "flags": flags,
        "warnings": warnings,
        "recommendations": [
            "Log a few sessions — ideally including one hard effort — to unlock predictions."
        ],
    }


# --------------------------------------------------------------------------------------
# Self-test / demonstration
# --------------------------------------------------------------------------------------

def _pace_for(tag: str, distance_m: float, s2k: float,
              config: EngineConfig = DEFAULT_CONFIG) -> float:
    """Forward model: the split this athlete would row at this tier and distance.

    The test fixtures are generated through this rather than hand-written, so they are
    physiologically self-consistent by construction. Hand-written fixtures were how the
    original draft ended up asserting a 6k at 2k pace.
    """
    tier = TIERS[tag]
    return (s2k
            + tier.paul_weight * config.paul_constant
            * math.log2(distance_m / tier.ref_distance_m)
            + tier.offset)


def _build_history(as_of: date, s2k: float = 105.0) -> list[dict[str, Any]]:
    """A club athlete with a true 2k of 1:45.0: steady volume, threshold work, one 6k."""
    plan = [
        ("UT2", 16000, 19),
        ("UT2", 14000, 20),
        ("UT1", 12000, 22),
        ("AT", 8000, 26),
        ("UT2", 18000, 18),
    ]
    sessions: list[dict[str, Any]] = []
    for week in range(4):
        for offset, (tag, distance, rate) in enumerate(plan):
            split = _pace_for(tag, distance, s2k)
            day = as_of - timedelta(days=week * 7 + offset)
            sessions.append({
                "id": f"w{week}-{offset}",
                "date": day.isoformat(),
                "distance_m": distance,
                "split_s": round(split, 1),
                "time_s": round(split * distance / 500.0, 1),
                "stroke_rate": rate,
                "tag": tag,
            })
    tr_split = _pace_for("TR", 6000, s2k)
    sessions.append({
        "id": "6k-tr",
        "date": (as_of - timedelta(days=9)).isoformat(),
        "distance_m": 6000,
        "time_s": round(tr_split * 6000 / 500.0, 1),
        "stroke_rate": 30,
        "tag": "TR",
    })
    return sessions


def _run_self_test() -> None:
    import json

    as_of = date(2026, 9, 17)
    failures: list[str] = []

    def check(name: str, condition: bool, detail: str = "") -> None:
        status = "PASS" if condition else "FAIL"
        print(f"  [{status}] {name}{(' — ' + detail) if detail else ''}")
        if not condition:
            failures.append(name)

    print("\n" + "=" * 78)
    print("0. Tier constants are mutually coherent")
    print("=" * 78)
    # Every tier, rowed at its own reference distance and at distances either side of it,
    # must invert back to the same S2k. This is the check that would have caught the
    # double-counting in both v1.0 and the v1.1 draft.
    for tag, tier in TIERS.items():
        for factor in (0.5, 1.0, 2.0):
            distance = tier.ref_distance_m * factor
            observed = _pace_for(tag, distance, 105.0)
            recovered, _, _ = _normalise_to_reference(observed, distance, tier, DEFAULT_CONFIG)
            if abs(recovered - 105.0) > 1e-9:
                check(f"{tag} at {distance:.0f}m inverts to S2k", False,
                      f"recovered {recovered:.4f}")
                break
        else:
            check(f"{tag} inverts to the same S2k at 0.5x, 1x and 2x its reference", True)

    print("\n" + "=" * 78)
    print("1. The v1.0 formula bug, demonstrated")
    print("=" * 78)
    ut2_split = _pace_for("UT2", 15000, 105.0)
    ut2_only = [{
        "id": "ut2-15k", "date": (as_of - timedelta(days=2)).isoformat(),
        "distance_m": 15000, "split_s": round(ut2_split, 1), "stroke_rate": 19, "tag": "UT2",
    }]
    legacy = predict_test_piece(
        ut2_only, 2000, as_of, replace(DEFAULT_CONFIG, legacy_v1_formula=True)
    )
    fixed = predict_test_piece(ut2_only, 2000, as_of)
    print(f"  input        : 15,000m UT2 at {format_seconds(ut2_split)}/500m "
          f"(a 1:45.0 2k rower)")
    print(f"  v1.0 formula : 2k of {legacy['predicted_total_time_formatted']} "
          f"(split {legacy['predicted_split_formatted']})")
    print(f"  v1.2 formula : 2k of {fixed['predicted_total_time_formatted']} "
          f"(split {fixed['predicted_split_formatted']})")
    delta = legacy["predicted_total_time_seconds"] - fixed["predicted_total_time_seconds"]
    print(f"  divergence   : {abs(delta):.1f} seconds over 2000m")
    check("v1.2 recovers the true 1:45.0 split from a UT2 anchor",
          abs(fixed["components"]["two_k_equivalent"] - 105.0) < 0.2,
          f"S2k = {format_seconds(fixed['components']['two_k_equivalent'])}")
    check("v1.0 was optimistic by more than 30s over 2k", abs(delta) > 30)

    print("\n" + "=" * 78)
    print("2. Self-consistency: a 2k test anchor must return roughly itself")
    print("=" * 78)
    an_test = [{
        "id": "2k-test", "date": (as_of - timedelta(days=3)).isoformat(),
        "distance_m": 2000, "time_s": "7:00.0", "stroke_rate": 34, "tag": "AN",
    }]
    result = predict_test_piece(an_test, 2000, as_of)
    print(f"  logged 7:00.0 -> predicted {result['predicted_total_time_formatted']} "
          f"({result['confidence_score']}, {result['confidence_numeric']}/100)")
    print(f"  load modifier: raw {result['load']['raw_modifier_seconds']}s "
          f"x confidence {result['load']['load_confidence']} "
          f"= {result['load']['modifier_seconds']}s")
    check("a lone 2k test is not contradicted by the detraining penalty",
          abs(result["predicted_split_seconds"] - 105.0) <= 0.6,
          f"predicted {result['predicted_split_formatted']}")

    print("\n" + "=" * 78)
    print("3. Realistic athlete (true 2k = 7:00.0), 2000m and 5000m")
    print("=" * 78)
    history = _build_history(as_of)
    for distance in (2000, 5000):
        r = predict_test_piece(history, distance, as_of)
        print(f"  {distance}m -> {r['predicted_total_time_formatted']} "
              f"@ {r['predicted_split_formatted']}/500m | "
              f"{r['confidence_score']} ({r['confidence_numeric']}/100) | "
              f"anchor {r['anchor']['tier']} via {r['anchor']['method']}")
    two_k = predict_test_piece(history, 2000, as_of)
    five_k = predict_test_piece(history, 5000, as_of)
    diag = two_k["diagnostics"]
    print(f"  cross-tier 2k equivalents: {diag['two_k_equivalent_formatted']}")
    print(f"  spread: {diag['spread_seconds']}s")
    check("2k prediction lands within 1s of the athlete's true 2k",
          abs(two_k["predicted_split_seconds"] - 105.0) <= 1.0,
          f"predicted {two_k['predicted_split_formatted']}")
    check("5k split is slower than 2k split",
          five_k["predicted_split_seconds"] > two_k["predicted_split_seconds"])
    check("TR test outranks the steady volume as anchor", two_k["anchor"]["tier"] == "TR")
    check("a consistently tagged athlete shows near-zero cross-tier spread",
          diag["spread_seconds"] < 1.0, f"{diag['spread_seconds']}s")
    check("a coherent 6k anchor for a 2k target reaches High confidence",
          two_k["confidence_score"] == "High",
          f"{two_k['confidence_score']} ({two_k['confidence_numeric']})")

    print("\n" + "=" * 78)
    print("4. Mis-tagged athlete is detected, not silently believed")
    print("=" * 78)
    # Same volume, but the 6k is logged at a pace no athlete rowing 2:07 UT2 could hold.
    mistagged_history = [s for s in _build_history(as_of) if s["id"] != "6k-tr"]
    mistagged_history.append({
        "id": "6k-implausible", "date": (as_of - timedelta(days=9)).isoformat(),
        "distance_m": 6000, "time_s": "21:00.0", "stroke_rate": 30, "tag": "TR",
    })
    mis = predict_test_piece(mistagged_history, 2000, as_of)
    print(f"  6k logged at 1:45.0/500 alongside 2:07 UT2 -> "
          f"{mis['predicted_total_time_formatted']}, {mis['confidence_score']}")
    print(f"  cross-tier spread: {mis['diagnostics']['spread_seconds']}s")
    check("internally contradictory tagging is flagged",
          "tier_disagreement" in mis["flags"])
    check("contradictory tagging costs confidence relative to the coherent athlete",
          mis["confidence_numeric"] < two_k["confidence_numeric"])

    print("\n" + "=" * 78)
    print("5. Edge cases")
    print("=" * 78)

    cold = predict_test_piece([], 2000, as_of)
    check("empty history returns a null prediction, not a guess",
          cold["predicted_split_seconds"] is None
          and cold["confidence_score"] == "Insufficient Data")

    check("None history is tolerated",
          predict_test_piece(None, 2000, as_of)["confidence_score"] == "Insufficient Data")

    zero_distance = predict_test_piece(
        [{"id": "bad", "date": as_of.isoformat(), "distance_m": 0,
          "time_s": 600, "tag": "UT2"}], 2000, as_of)
    check("zero-distance session is rejected without dividing by zero",
          zero_distance["predicted_split_seconds"] is None
          and any("positive" in w for w in zero_distance["warnings"]))

    zero_target = predict_test_piece(history, 0, as_of)
    check("zero target distance is rejected without a log-domain error",
          zero_target["predicted_split_seconds"] is None
          and "invalid_target_distance" in zero_target["flags"])

    check("negative target distance is rejected",
          predict_test_piece(history, -2000, as_of)["predicted_split_seconds"] is None)

    check("non-numeric target distance is rejected",
          predict_test_piece(history, "two thousand", as_of)[
              "predicted_split_seconds"] is None)

    stale = predict_test_piece(
        [{"id": "old", "date": (as_of - timedelta(days=120)).isoformat(),
          "distance_m": 2000, "time_s": 420, "tag": "AN"}], 2000, as_of)
    check("history entirely outside the window yields no prediction",
          stale["predicted_split_seconds"] is None
          and "history_outside_window" in stale["flags"])

    future = predict_test_piece(
        history + [{"id": "tomorrow", "date": (as_of + timedelta(days=1)).isoformat(),
                    "distance_m": 2000, "time_s": 360, "tag": "AN"}], 2000, as_of)
    check("future-dated sessions are dropped",
          "future_dated_session" in future["flags"] and future["anchor"]["tier"] == "TR")

    malformed = predict_test_piece(
        history + ["not a dict", {"date": "nonsense", "distance_m": 2000, "tag": "AN"},
                   {"date": as_of.isoformat(), "distance_m": 2000, "tag": "XX",
                    "time_s": 400}],
        2000, as_of)
    check("malformed rows are skipped with named warnings, others still used",
          malformed["predicted_split_seconds"] is not None
          and len(malformed["warnings"]) >= 3)

    intervals = predict_test_piece(
        [{"id": "8x500", "date": (as_of - timedelta(days=4)).isoformat(),
          "distance_m": 4000, "split_s": 96.0, "stroke_rate": 34, "tag": "AN"}],
        2000, as_of)
    declared = predict_test_piece(
        [{"id": "8x500", "date": (as_of - timedelta(days=4)).isoformat(),
          "distance_m": 4000, "rep_distance_m": 500, "split_s": 96.0,
          "stroke_rate": 34, "tag": "AN"}],
        2000, as_of)
    check("undeclared interval structure is flagged and costs confidence",
          "interval_structure_ambiguous" in intervals["flags"])
    check("declaring rep distance clears the flag and changes the answer",
          "interval_structure_ambiguous" not in declared["flags"]
          and declared["predicted_split_seconds"] != intervals["predicted_split_seconds"],
          f"{intervals['predicted_split_formatted']} -> "
          f"{declared['predicted_split_formatted']}")

    mistag_rate = predict_test_piece(
        [{"id": "odd", "date": (as_of - timedelta(days=1)).isoformat(),
          "distance_m": 10000, "split_s": 125.0, "stroke_rate": 36, "tag": "UT2"}],
        2000, as_of)
    check("stroke rate inconsistent with the tag is flagged",
          "anchor_tag_rate_mismatch" in mistag_rate["flags"])

    absurd = predict_test_piece(
        [{"id": "typo", "date": (as_of - timedelta(days=1)).isoformat(),
          "distance_m": 2000, "split_s": 60.0, "stroke_rate": 34, "tag": "AN"}],
        2000, as_of)
    check("faster-than-world-record input is clamped rather than displayed",
          "clamped_to_physiological_floor" in absurd["flags"])
    check("a clamped prediction can never be shown above Low confidence",
          absurd["confidence_score"] == "Low",
          f"{absurd['confidence_score']} ({absurd['confidence_numeric']})")

    mismatch = predict_test_piece(
        [{"id": "disagree", "date": (as_of - timedelta(days=1)).isoformat(),
          "distance_m": 10000, "time_s": 2600, "split_s": 118.0,
          "stroke_rate": 20, "tag": "UT2"}], 2000, as_of)
    check("split disagreeing with time/distance prefers the derived value",
          any("disagrees" in w for w in mismatch["warnings"]))

    aliased = predict_test_piece(
        [{"ID": "csv-row", "Date": "17/09/2026", "Total Distance (meters)": 6000,
          "Total Time": "23:06.0", "Average Stroke Rate": 30, "Zone": "tr"}],
        2000, as_of)
    check("Concept2 CSV headings and lowercase tags are accepted",
          aliased["predicted_split_seconds"] is not None
          and aliased["anchor"]["tier"] == "TR")

    check("duration parser handles h:mm:ss.s", parse_duration("1:23:45.6") == 5025.6)
    check("duration parser handles mm:ss.s", parse_duration("6:50.2") == 410.2)
    check("duration parser rejects rubbish", parse_duration("abc") is None)
    check("duration parser rejects zero", parse_duration(0) is None)
    check("duration parser rejects booleans", parse_duration(True) is None)
    check("formatter renders sub-hour", format_seconds(421.2) == "7:01.2")
    check("formatter renders past the hour", format_seconds(5025.6) == "1:23:45.6")
    check("formatter carries 59.96s up to the next minute",
          format_seconds(419.96) == "7:00.0", format_seconds(419.96))
    check("formatter carries across the hour boundary",
          format_seconds(3599.99) == "1:00:00.0", format_seconds(3599.99))

    ut1_only = predict_test_piece(
        [{"id": f"ut1-{i}", "date": (as_of - timedelta(days=i)).isoformat(),
          "distance_m": 12000, "split_s": round(_pace_for("UT1", 12000, 105.0), 1),
          "stroke_rate": 22, "tag": "UT1"} for i in range(1, 8)], 2000, as_of)
    check("UT1-only history produces an anchor (v1.0 had no UT1 rank)",
          ut1_only["anchor"] is not None and ut1_only["anchor"]["tier"] == "UT1")
    check("UT1-only history is capped at Low confidence",
          ut1_only["confidence_score"] == "Low")
    check("UT2-only history is capped at Low confidence",
          predict_test_piece(ut2_only, 2000, as_of)["confidence_score"] == "Low")

    check("every result is JSON-serialisable",
          isinstance(json.dumps(predict_test_piece(history, 2000, as_of)), str))

    print("\n" + "=" * 78)
    print("6. Demographics cannot leak into an anchored prediction")
    print("=" * 78)
    baseline = predict_test_piece(history, 2000, as_of)
    young = predict_test_piece(history, 2000, as_of,
                               athlete={"age": 22, "sex": "male", "weight_kg": 95})
    older = predict_test_piece(history, 2000, as_of,
                               athlete={"age": 68, "sex": "female", "weight_kg": 55})
    print(f"  no profile           -> {baseline['predicted_total_time_formatted']}")
    print(f"  22yo male, 95kg      -> {young['predicted_total_time_formatted']}")
    print(f"  68yo female, 55kg    -> {older['predicted_total_time_formatted']}")
    check("identical history gives identical prediction whatever the demographics",
          baseline["predicted_split_seconds"] == young["predicted_split_seconds"]
          == older["predicted_split_seconds"])
    check("profile is reported as not used in the prediction",
          young["athlete"]["used_in_prediction"] is False)

    print("\n" + "=" * 78)
    print("7. Perceived effort (RPE)")
    print("=" * 78)

    def ut2_at_rpe(rpe: Any) -> dict[str, Any]:
        rows = [{"id": f"u{i}", "date": (as_of - timedelta(days=i)).isoformat(),
                 "distance_m": 16000, "split_s": 127.0, "stroke_rate": 19,
                 "tag": "UT2", "rpe": rpe} for i in range(1, 8)]
        return predict_test_piece(rows, 2000, as_of)

    mid, harder, easier = ut2_at_rpe(3), ut2_at_rpe(4), ut2_at_rpe(2)
    print(f"  UT2 16k @ 2:07.0, RPE 2 -> 2k {easier['predicted_total_time_formatted']}")
    print(f"  UT2 16k @ 2:07.0, RPE 3 -> 2k {mid['predicted_total_time_formatted']}")
    print(f"  UT2 16k @ 2:07.0, RPE 4 -> 2k {harder['predicted_total_time_formatted']}")
    check("RPE at the tier midpoint applies no correction",
          mid["components"]["rpe_correction"] == 0.0)
    check("a session that felt harder implies a slower 2k",
          harder["predicted_split_seconds"] > mid["predicted_split_seconds"],
          f"{harder['components']['rpe_correction']:+.1f}s")
    check("a session that felt easier implies a faster 2k",
          easier["predicted_split_seconds"] < mid["predicted_split_seconds"],
          f"{easier['components']['rpe_correction']:+.1f}s")
    check("RPE corrections are symmetric about the midpoint",
          abs(harder["components"]["rpe_correction"]
              + easier["components"]["rpe_correction"]) < 1e-9)

    contradicted = ut2_at_rpe(9)
    check("RPE wildly inconsistent with the tag is flagged, not applied",
          "anchor_tag_rpe_mismatch" in contradicted["flags"]
          and contradicted["components"]["rpe_correction"] == 0.0)
    check("an RPE contradiction costs confidence",
          contradicted["confidence_numeric"] < mid["confidence_numeric"])

    aggressive = replace(DEFAULT_CONFIG, rpe_sensitivity=10.0)
    capped = predict_test_piece(
        [{"id": "c", "date": (as_of - timedelta(days=1)).isoformat(),
          "distance_m": 16000, "split_s": 127.0, "tag": "UT2", "rpe": 5}],
        2000, as_of, aggressive)
    check("the RPE correction is capped",
          capped["components"]["rpe_correction"] == DEFAULT_CONFIG.rpe_max_correction)

    check("Borg 6-20 values are converted onto CR10",
          abs(_normalise_rpe(15) - (15 - 6) / 1.4) < 1e-9)
    check("out-of-range RPE is discarded rather than clamped",
          _normalise_rpe(42) is None and _normalise_rpe(-1) is None)
    check("no RPE logged leaves the v1.2 behaviour untouched",
          baseline["components"]["rpe_correction"] == 0.0
          and baseline["effort"]["sessions_with_rpe"] == 0)

    tired = [dict(s) for s in history]
    for s in tired:
        if s["tag"] == "UT2" and (as_of - parse_date(s["date"])).days <= 7:
            s["rpe"] = 5.5   # UT2 midpoint is 3.0; this is a sustained +2.5 excess
    tired_result = predict_test_piece(tired, 2000, as_of)
    print(f"  recent UT2 rows rated +2.5 RPE -> excess "
          f"{tired_result['effort']['recent_rpe_excess']}, "
          f"confidence {tired_result['confidence_numeric']}")
    check("a sustained RPE excess is read as fatigue",
          "elevated_recent_effort" in tired_result["flags"])
    check("the fatigue read changes confidence and advice, not the anchor's pace",
          tired_result["components"]["two_k_equivalent"]
          == baseline["components"]["two_k_equivalent"]
          and tired_result["confidence_numeric"] < baseline["confidence_numeric"])

    print("\n" + "=" * 78)
    print("8. Bodyweight")
    print("=" * 78)
    factor_80 = weight_adjustment_factor(80.0)
    expected = (80.0 * 2.2046226218 / 270.0) ** 0.222
    print(f"  Concept2 weight factor at 80kg: {factor_80:.4f}")
    check("weight factor matches the published Concept2 formula",
          abs(factor_80 - expected) < 1e-12)
    check("weight factor is 1.0 at the 270lb reference",
          abs(weight_adjustment_factor(270 / 2.2046226218) - 1.0) < 1e-12)

    with_weight = predict_test_piece(history, 2000, as_of, athlete={"weight_kg": 80})
    wa = with_weight["interpretation"]["weight_adjusted"]
    print(f"  7:00.0 at 80kg -> weight-adjusted {wa['total_time_formatted']}")
    check("weight-adjusted score is raw time x Wf",
          abs(wa["total_time_seconds"]
              - with_weight["predicted_total_time_seconds"] * factor_80) < 0.02)

    def weighed_history(start_kg: float, end_kg: float) -> list[dict[str, Any]]:
        rows = [dict(s) for s in history]
        for s in rows:
            days_ago = (as_of - parse_date(s["date"])).days
            # Linear weight change across the window, oldest heaviest.
            s["bodyweight_kg"] = end_kg + (start_kg - end_kg) * days_ago / 30.0
        return rows

    cutting = weighed_history(80.0, 74.0)
    default_off = predict_test_piece(cutting, 2000, as_of)
    check("weight change is detected but not applied by default",
          "weight_change_not_applied" in default_off["flags"]
          and default_off["predicted_split_seconds"] == baseline["predicted_split_seconds"])

    trend_on = replace(DEFAULT_CONFIG, weight_trend_sensitivity=1.0)
    lighter = predict_test_piece(cutting, 2000, as_of, trend_on)
    heavier = predict_test_piece(weighed_history(74.0, 80.0), 2000, as_of, trend_on)
    print(f"  trend enabled, 80 -> 74kg -> {lighter['predicted_total_time_formatted']} "
          f"({lighter['components']['weight_trend_correction']:+.2f}s/500m)")
    print(f"  trend enabled, 74 -> 80kg -> {heavier['predicted_total_time_formatted']} "
          f"({heavier['components']['weight_trend_correction']:+.2f}s/500m)")
    check("when enabled, losing weight predicts a slower raw erg score",
          lighter["predicted_split_seconds"] > baseline["predicted_split_seconds"])
    check("when enabled, gaining weight predicts a faster raw erg score",
          heavier["predicted_split_seconds"] < baseline["predicted_split_seconds"])

    print("\n" + "=" * 78)
    print("9. Age grading")
    print("=" * 78)
    for age in (16, 22, 27, 40, 55, 70):
        print(f"  age {age:>2}: factor {age_performance_factor(age):.3f}")
    at_ref = predict_test_piece(history, 2000, as_of, athlete={"age": 27})
    at_55 = predict_test_piece(history, 2000, as_of, athlete={"age": 55})
    check("age grading is neutral at the reference age",
          at_ref["interpretation"]["age_graded"]["total_time_seconds"]
          == at_ref["predicted_total_time_seconds"])
    check("an older athlete's age-graded time is faster than their raw time",
          at_55["interpretation"]["age_graded"]["total_time_seconds"]
          < at_55["predicted_total_time_seconds"],
          at_55["interpretation"]["age_graded"]["total_time_formatted"])
    check("age curve is monotonic from the reference age upward",
          all(age_performance_factor(a) <= age_performance_factor(a + 1)
              for a in range(27, 95)))
    check("age curve is monotonic from the reference age downward",
          all(age_performance_factor(a) >= age_performance_factor(a + 1)
              for a in range(8, 27)))
    check("age-graded output names its source and is not an official standard",
          "Concept2 rankings" in at_55["interpretation"]["age_graded"]["method"]
          and "not an official standard" in at_55["interpretation"]["age_graded"]["method"])
    check("age curve passes through every fitted knot",
          all(abs(age_performance_factor(a) - (1.0 + f)) < 1e-12
              for a, f in DEFAULT_CONFIG.prior_age_curve))
    check("age curve is continuous at the reference age",
          abs(age_performance_factor(26.999) - age_performance_factor(27.0)) < 1e-4)

    print("\n" + "=" * 78)
    print("10. Cold start with a profile")
    print("=" * 78)
    for profile_raw in ({"age": 27, "sex": "male", "weight_kg": 82},
                        {"age": 27, "sex": "female", "weight_kg": 68},
                        {"age": 27, "sex": "nonbinary", "weight_kg": 75},
                        {"age": 55, "sex": "male", "weight_kg": 82}):
        r = predict_test_piece([], 2000, as_of, athlete=profile_raw)
        print(f"  {str(profile_raw):<52} -> {r['predicted_total_time_formatted']} "
              f"({r['confidence_score']})")
    male_prior = predict_test_piece([], 2000, as_of,
                                    athlete={"age": 27, "sex": "male", "weight_kg": 82})
    check("a profile with no history returns a labelled population estimate",
          male_prior["confidence_score"] == "Population Estimate"
          and "population_estimate" in male_prior["flags"]
          and male_prior["anchor"] is None)
    check("the reference male prior reproduces its fitted baseline",
          abs(male_prior["predicted_total_time_seconds"]
              - DEFAULT_CONFIG.prior_male_2k_seconds) < 0.05)
    check("population estimate is flagged with its source",
          "prior_from_concept2_rankings" in male_prior["flags"])
    heavier_prior = predict_test_piece([], 2000, as_of,
                                       athlete={"sex": "male", "weight_kg": 100})
    check("a heavier athlete's prior is faster (weight^-0.222)",
          heavier_prior["predicted_split_seconds"] < male_prior["predicted_split_seconds"])
    older_prior = predict_test_piece([], 2000, as_of,
                                     athlete={"age": 55, "sex": "male", "weight_kg": 82})
    check("an older athlete's prior is slower",
          older_prior["predicted_split_seconds"] > male_prior["predicted_split_seconds"])
    neutral = predict_test_piece([], 2000, as_of, athlete={"sex": "nonbinary"})
    check("an unrecognised sex value routes to the neutral prior without error",
          "sex_neutral_prior" in neutral["flags"]
          and neutral["predicted_split_seconds"] is not None)
    check("a real anchor always outranks the population prior",
          predict_test_piece(an_test, 2000, as_of,
                             athlete={"age": 70, "sex": "female"})["anchor"] is not None)
    junk = predict_test_piece([], 2000, as_of, athlete={"age": 400, "weight_kg": -3})
    check("implausible age and weight are dropped with warnings",
          junk["confidence_score"] == "Insufficient Data"
          and sum("ignored" in w for w in junk["warnings"]) == 2)
    check("population estimates are JSON-serialisable",
          isinstance(json.dumps(male_prior), str))

    print("\n" + "=" * 78)
    print("11. Audit regressions (v1.3.1)")
    print("=" * 78)

    leak_rows = [
        {"id": "a", "date": (as_of - timedelta(days=1)).isoformat(), "distance_m": 8000,
         "split_s": 127.0, "tag": "UT2", "rpe": 3},
        {"id": "b", "date": (as_of - timedelta(days=2)).isoformat(), "distance_m": 8000,
         "split_s": 127.0, "tag": "UT2", "rpe": 3},
        {"id": "c", "date": (as_of - timedelta(days=3)).isoformat(), "distance_m": 20000,
         "split_s": 127.0, "tag": "UT2", "rpe": 9},
    ] + [{"id": f"x{i}", "date": (as_of - timedelta(days=i)).isoformat(),
          "distance_m": 8000, "split_s": 127.0, "tag": "UT2"} for i in range(4, 7)]
    leak = predict_test_piece(leak_rows, 2000, as_of)
    check("a contradicted RPE cannot become the tier median and move the pace",
          leak["components"]["rpe_correction"] == 0.0,
          f"correction {leak['components']['rpe_correction']:+.2f}")

    sparse_rows = [{"id": f"s{i}", "date": (as_of - timedelta(days=i)).isoformat(),
                    "distance_m": 16000, "split_s": 127.0, "tag": "UT2"}
                   for i in range(1, 20)]
    sparse_rows[0]["rpe"] = 5.0
    sparse = predict_test_piece(sparse_rows, 2000, as_of)
    check("one rated session among nineteen barely moves the tier",
          abs(sparse["components"]["rpe_correction"]) < 0.25,
          f"{sparse['components']['rpe_correction']:+.2f}s")

    stale_test = [{"id": "old", "date": (as_of - timedelta(days=45)).isoformat(),
                   "distance_m": 2000, "time_s": "6:30.0", "tag": "AN"}]
    stale_with_profile = predict_test_piece(stale_test, 2000, as_of,
                                            athlete={"sex": "male", "age": 30})
    check("a stale real result is never replaced by a population estimate",
          stale_with_profile["confidence_score"] != "Population Estimate"
          and "history_outside_window" in stale_with_profile["flags"])

    def an_at(rpe: float) -> float:
        return predict_test_piece(
            [{"id": "t", "date": (as_of - timedelta(days=2)).isoformat(),
              "distance_m": 2000, "time_s": "7:00.0", "tag": "AN", "rpe": rpe}],
            2000, as_of)["predicted_split_seconds"]
    check("RPE cannot move an all-out test away from the time actually rowed",
          an_at(8.0) == an_at(9.5) == an_at(10.0))

    check("RPE between 10 and 11 is rejected, not read as an easy Borg value",
          _normalise_rpe(10.5) is None)

    weighed = [dict(s) for s in history]
    for s in weighed:
        s["bodyweight_kg"] = 80.0
    mismatch_profile = predict_test_piece(weighed, 2000, as_of, athlete={"weight_kg": 74})
    check("undated profile weight vs logged weigh-ins is not read as a weight trend",
          "weight_change_not_applied" not in mismatch_profile["flags"]
          and "weight_trend_applied" not in mismatch_profile["flags"])

    trend_rows = [dict(s) for s in history]
    for s in trend_rows:
        days_ago = (as_of - parse_date(s["date"])).days
        s["bodyweight_kg"] = 74.0 + 6.0 * days_ago / 30.0
    trended = predict_test_piece(trend_rows, 2000, as_of,
                                 replace(DEFAULT_CONFIG, weight_trend_sensitivity=1.0))
    expected_trend = 105.0 * ((74.0 / 75.8) ** -0.222 - 1.0)
    check("weight trend scales the predicted split, not the anchor's training split",
          abs(trended["components"]["weight_trend_correction"] - expected_trend) < 0.01,
          f"{trended['components']['weight_trend_correction']:+.3f} vs {expected_trend:+.3f}")

    duplicated = history + [dict(history[0]), dict(history[1])]
    dup = predict_test_piece(duplicated, 2000, as_of)
    check("duplicate session ids are counted once",
          dup["load"]["trimp_lite"] == baseline["load"]["trimp_lite"]
          and "duplicate_sessions_removed" in dup["flags"])
    edited = history + [dict(history[0], split_s=999.0, time_s=None)]
    edited_result = predict_test_piece(edited, 2000, as_of)
    check("for a duplicated id, the latest copy wins",
          any("implausible split" in w for w in edited_result["warnings"]))

    all_contradicted = predict_test_piece(
        [{"id": f"k{i}", "date": (as_of - timedelta(days=i)).isoformat(),
          "distance_m": 16000, "split_s": 127.0, "tag": "UT2", "rpe": 9}
         for i in range(1, 8)], 2000, as_of)
    check("a tier where every rating contradicts its tag is flagged without crashing",
          "anchor_tag_rpe_mismatch" in all_contradicted["flags"]
          and all_contradicted["components"]["rpe_correction"] == 0.0)

    print("\n" + "=" * 78)
    print("12. Full output shape (with profile and RPE)")
    print("=" * 78)
    rated_history = [dict(s, rpe=TIERS[s["tag"]].rpe_mid) for s in history]
    print(json.dumps(predict_test_piece(
        rated_history, 2000, as_of,
        athlete={"age": 21, "sex": "male", "weight_kg": 80}), indent=2))

    print("\n" + "=" * 78)
    if failures:
        print(f"{len(failures)} CHECK(S) FAILED:")
        for name in failures:
            print(f"  - {name}")
    else:
        print("All checks passed.")
    print("=" * 78 + "\n")


if __name__ == "__main__":
    _run_self_test()
