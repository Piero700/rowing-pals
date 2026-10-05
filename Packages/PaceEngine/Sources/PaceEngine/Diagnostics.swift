//
//  Diagnostics.swift
//  PaceEngine
//
//  Port of `diagnose_history`.
//

import Foundation

/// An independent 2000m-equivalent from each tier present. Both a confidence input (the
/// spread) and the calibration harness of SPEC.md §6.2.
///
/// Like the Python, this re-reads the whole de-duplicated history — future-dated rows
/// included — and applies its own window, rather than reusing the prediction's filtered
/// list. Estimates are rounded to 2 dp BEFORE the spread is taken, and the predictor compares
/// that rounded spread with the tolerance, so the order of rounding is kept.
func diagnoseHistory(
    _ history: [SessionInput],
    days: [Int],
    asOfDay: Int,
    config: EngineConfig
) -> Prediction.Diagnostics {
    var warnings: [String] = []
    let sessions = history.enumerated().compactMap { index, raw in
        normaliseSession(raw, index: index, day: days[index], config: config, warnings: &warnings)
    }
    .filter { asOfDay - config.windowDays <= $0.day && $0.day <= asOfDay }

    var estimates: [(tag: Tier.Name, value: Double)] = []
    for tier in Tier.all {
        let candidates = sessions.filter { $0.tag == tier.name }
        if candidates.isEmpty { continue }

        let split: Double
        let distance: Double
        let rpe: Double?
        let rpeMismatch: Bool
        let coverage: Double
        if tier.isMaximal {
            // Best effort represents the tier; a slow rep set is not evidence of a ceiling.
            guard let representative = Py.firstMin(candidates, by: { $0.splitS < $1.splitS }) else { continue }
            split = representative.splitS
            distance = representative.effectiveDistanceM
            rpe = representative.rpe
            rpeMismatch = representative.rpeMismatch
            coverage = 1.0
        } else {
            split = weightedMedian(candidates.map { ($0.splitS, $0.durationMinutes) })
            distance = weightedMedian(candidates.map { ($0.effectiveDistanceM, $0.durationMinutes) })
            let effort = tierRPE(candidates)
            rpe = effort.rpe
            rpeMismatch = effort.mismatch
            coverage = effort.coverage
        }
        var reference = normaliseToReference(split: split, effectiveDistanceM: distance,
                                              tier: tier, config: config).s2k
        // Same RPE correction as the prediction path.
        reference += rpeOffsetCorrection(rpe: rpe, tier: tier, rpeMismatch: rpeMismatch,
                                         config: config) * coverage
        estimates.append((tier.name, Py.round(reference, 2)))
    }

    var spread = 0.0
    if estimates.count > 1, let high = estimates.map(\.value).max(), let low = estimates.map(\.value).min() {
        spread = high - low
    }

    var byTier: [String: Double] = [:]
    var formatted: [String: String] = [:]
    for estimate in estimates {
        byTier[estimate.tag.rawValue] = estimate.value
        formatted[estimate.tag.rawValue] = formatSeconds(estimate.value)
    }
    return Prediction.Diagnostics(
        twoKEquivalentByTier: byTier,
        twoKEquivalentFormatted: formatted,
        spreadSeconds: Py.round(spread, 2),
        tiersRepresented: estimates.count,
        warnings: warnings
    )
}
