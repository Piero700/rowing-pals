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
    // v1.7: volume-only rows never carry pace; the rower's own Paul's Law reads every all-out
    // piece up to today, not just the window (§5.21).
    let parsed = history.enumerated().compactMap { index, raw in
        normaliseSession(raw, index: index, day: days[index], config: config, warnings: &warnings)
    }
    .filter { $0.day <= asOfDay && !$0.volumeOnly }
    let sessions = parsed.filter { $0.day >= asOfDay - config.windowDays }
    let paul = PersonalPaul.fit(parsed, asOfDay: asOfDay, config: config).secondsPerDoubling

    var estimates: [(tag: Tier.Name, value: Double)] = []
    for tier in Tier.all {
        let candidates = sessions.filter { $0.tag == tier.name }
        if candidates.isEmpty { continue }

        let reference: Double
        if tier.isMaximal {
            // Best effort represents the tier; a slow rep set is not evidence of a ceiling.
            guard let representative = Py.firstMin(candidates, by: { $0.splitS < $1.splitS }) else { continue }
            reference = normaliseToReference(split: representative.splitS,
                                             effectiveDistanceM: representative.effectiveDistanceM,
                                             tier: tier, config: config, paul: paul).s2k
                + rpeOffsetCorrection(rpe: representative.rpe, tier: tier,
                                      rpeMismatch: representative.rpeMismatch, config: config)
        } else {
            // v1.7: each piece's own 2k equivalent (RPE scaled by the zone's rated coverage,
            // rate corrected), then the duration-weighted median — the prediction path's model.
            let coverage = tierRPE(candidates).coverage
            reference = weightedMedian(candidates.map { session in
                let s2k = normaliseToReference(split: session.splitS,
                                               effectiveDistanceM: session.effectiveDistanceM,
                                               tier: tier, config: config).s2k
                let rpe = rpeOffsetCorrection(rpe: session.rpe, tier: tier,
                                              rpeMismatch: session.rpeMismatch, config: config) * coverage
                let rate = rateCorrection(rate: session.strokeRate, tier: tier, config: config)
                return (s2k + rpe + rate, session.durationMinutes)
            })
        }
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
