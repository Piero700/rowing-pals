//
//  Model.swift
//  PaceEngine
//
//  Port of `_normalise_to_reference`, `_interpolate`, `_rolling_load`,
//  `_rpe_offset_correction`, `weight_adjustment_factor`, `_age_penalty_fraction`,
//  `age_performance_factor`, `_population_prior_2k` and `_weight_trend_correction`.
//

import Foundation

/// Inverts the session model to recover the athlete's maximal 2000m split:
/// `S2k = observed − w_T × 5 × log2(d / ref_T) − g_T`. Returns (S2k, paul adjustment,
/// intensity offset) — the signed contributions actually applied.
func normaliseToReference(
    split: Double,
    effectiveDistanceM: Double,
    tier: Tier,
    config: EngineConfig
) -> (s2k: Double, paulAdjustment: Double, intensityOffset: Double) {
    precondition(effectiveDistanceM > 0, "effective distance must be positive")
    let ratio = effectiveDistanceM / tier.refDistanceM
    let paulAdjustment = -tier.paulWeight * config.paulConstant * log2(ratio)
    let intensityOffset = -tier.offset
    return (split + paulAdjustment + intensityOffset, paulAdjustment, intensityOffset)
}

/// Piecewise-linear interpolation with flat extrapolation beyond the end knots.
func interpolate(_ knots: [EngineConfig.LoadKnot], _ x: Double) -> Double {
    // `sorted(knots)` sorts the (x, y) tuples.
    let points = Py.stableSorted(knots) { lhs, rhs in
        lhs.load < rhs.load || (lhs.load == rhs.load && lhs.modifierSeconds < rhs.modifierSeconds)
    }
    guard let first = points.first, let last = points.last else { return 0.0 }
    if x <= first.load { return first.modifierSeconds }
    if x >= last.load { return last.modifierSeconds }
    for (p0, p1) in zip(points, points.dropFirst()) {
        let (x0, y0, x1, y1) = (p0.load, p0.modifierSeconds, p1.load, p1.modifierSeconds)
        if x0 <= x && x <= x1 {
            if x1 == x0 { return y1 }
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
        }
    }
    return last.modifierSeconds
}

/// TRIMP-lite: duration in minutes times the tier's intensity multiplier, summed.
func rollingLoad(_ sessions: [Session]) -> Double {
    Py.sum(sessions.map { $0.durationMinutes * $0.tier.load })
}

/// Seconds to ADD to the recovered S2k given how hard the anchor felt. 0 when RPE is absent,
/// when it contradicts the tag, and always for AN (an all-out test is the measurement itself).
func rpeOffsetCorrection(rpe: Double?, tier: Tier, rpeMismatch: Bool, config: EngineConfig) -> Double {
    guard let rpe, !rpeMismatch, tier.name != .an else { return 0.0 }
    let raw = config.rpeSensitivity * (rpe - tier.rpeMid)
    return Py.max(-config.rpeMaxCorrection, Py.min(config.rpeMaxCorrection, raw))
}

/// Concept2's published weight factor: `Wf = (lbs / 270) ^ 0.222`; corrected time = actual × Wf.
/// Nil for a weight that isn't positive (the Python raises).
public func weightAdjustmentFactor(weightKg: Double, config: EngineConfig = .default) -> Double? {
    guard weightKg > 0 else { return nil }
    let pounds = weightKg * 2.2046226218
    return pow(pounds / config.weightAdjustReferenceLb, config.weightAdjustExponent)
}

/// Fractional slowdown in expected 2k time relative to the reference age. SEED CURVE.
func agePenaltyFraction(age: Double, referenceAge: Double) -> Double {
    if age < referenceAge {
        if age >= 18.0 {
            let span = Py.max(referenceAge - 18.0, 1e-9)
            return 0.06 * (referenceAge - age) / span
        }
        return 0.06 + 0.025 * (18.0 - age)
    }
    var fraction = 0.0
    for (lo, hi, rate) in [(35.0, 50.0, 0.004), (50.0, 70.0, 0.008), (70.0, 120.0, 0.012)] {
        if age > lo {
            fraction += (Py.min(age, hi) - lo) * rate
        }
    }
    return fraction
}

/// Multiplier on expected 2k time relative to the reference age; 1.0 when unknown.
public func agePerformanceFactor(age: Double?, config: EngineConfig = .default) -> Double {
    guard let age else { return 1.0 }
    return 1.0 + agePenaltyFraction(age: age, referenceAge: config.priorReferenceAge)
}

/// A population estimate of 2k time in seconds, from demographics alone, with notes
/// explaining each adjustment. Used ONLY when there is no training history at all.
func populationPrior2k(_ athlete: Athlete, config: EngineConfig) -> (seconds: Double, notes: [String]) {
    var notes: [String] = []
    var base: Double
    let referenceKg: Double

    if athlete.sex == "male" {
        base = config.priorMale2kSeconds
        referenceKg = config.priorMaleReferenceKg
        notes.append("male population baseline \(formatSeconds(base) ?? "")")
    } else if athlete.sex == "female" {
        base = config.priorFemale2kSeconds
        referenceKg = config.priorFemaleReferenceKg
        notes.append("female population baseline \(formatSeconds(base) ?? "")")
    } else {
        base = (config.priorMale2kSeconds + config.priorFemale2kSeconds) / 2.0
        referenceKg = (config.priorMaleReferenceKg + config.priorFemaleReferenceKg) / 2.0
        notes.append("sex-neutral population baseline \(formatSeconds(base) ?? "") (wider uncertainty)")
    }

    // Comparing different people is what the Concept2 formula is for, so full strength here.
    if let weight = athlete.weightKg {
        let scale = pow(referenceKg / weight, config.weightAdjustExponent)
        base *= scale
        notes.append("weight \(Py.g(weight))kg vs reference \(Py.g(referenceKg))kg "
            + "(\(String(format: "%+.1f", (scale - 1) * 100))%)")
    }

    if let age = athlete.age {
        let factor = agePerformanceFactor(age: age, config: config)
        base *= factor
        notes.append("age \(Py.g(age)) (\(String(format: "%+.1f", (factor - 1) * 100))%)")
    }

    return (base, notes)
}

/// Seconds per 500m to add for bodyweight change since the anchor, from DATED session
/// weigh-ins only (nearest the anchor day, and the most recent). Scales the projected split.
/// Returns (correction, anchor weight, current weight).
func weightTrendCorrection(
    window: [Session],
    anchor: Anchor,
    baseSplit: Double,
    config: EngineConfig
) -> (correction: Double, anchorWeight: Double?, currentWeight: Double?) {
    let weighed = Py.stableSorted(window.filter { $0.bodyweightKg != nil }) { $0.day < $1.day }
    guard let nearest = Py.firstMin(weighed, by: { abs($0.day - anchor.day) < abs($1.day - anchor.day) }),
          let latest = weighed.last,
          let anchorWeight = nearest.bodyweightKg,
          let currentWeight = latest.bodyweightKg
    else {
        return (0.0, nil, nil)
    }

    if config.weightTrendSensitivity == 0.0
        || abs(currentWeight - anchorWeight) < config.weightTrendMinKg {
        return (0.0, anchorWeight, currentWeight)
    }

    let ratio = pow(currentWeight / anchorWeight, -config.weightAdjustExponent)
    let correction = baseSplit * (ratio - 1.0) * config.weightTrendSensitivity
    return (correction, anchorWeight, currentWeight)
}
