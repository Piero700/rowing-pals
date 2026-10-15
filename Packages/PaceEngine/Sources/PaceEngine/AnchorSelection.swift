//
//  AnchorSelection.swift
//  PaceEngine
//
//  Port of `Anchor`, `_weighted_median`, `_select_anchor` and `_tier_rpe`.
//

import Foundation

/// The session (or tier aggregate) the prediction is recovered from.
struct Anchor {
    let tag: Tier.Name
    let splitS: Double
    let effectiveDistanceM: Double
    let day: Int
    /// The date of `day`, for `isoformat()` output.
    let date: Date
    let sessionIds: [String]
    let method: String
    let intervalAmbiguous: Bool
    let rateMismatch: Bool
    var rpe: Double?
    var rpeMismatch = false
    /// Share of the anchor's duration carrying a usable RPE.
    var rpeCoverage = 1.0
    /// The piece that weighs most is a best the rower typed in (v1.6).
    var declared = false

    var tier: Tier { Tier.named(tag) }
}

/// `_weighted_median` of (value, weight) pairs: sort by value (stably, as Python does), walk
/// the running weight, and return the first value where it reaches half the total. With a
/// total weight of zero or less, the element at `count / 2`.
func weightedMedian(_ pairs: [(value: Double, weight: Double)]) -> Double {
    precondition(!pairs.isEmpty, "cannot take the median of an empty sequence")
    let ordered = Py.stableSorted(pairs) { $0.value < $1.value }
    let total = Py.sum(ordered.map(\.weight))
    if total <= 0 {
        return ordered[ordered.count / 2].value
    }
    var running = 0.0
    for pair in ordered {
        running += pair.weight
        if running >= total / 2.0 {
            return pair.value
        }
    }
    return ordered[ordered.count - 1].value
}

/// `_tier_rpe`: (median RPE, coverage, majority mismatch) for a submaximal tier. Only ratings
/// consistent with their tag enter the median; coverage is the rated share of the duration.
func tierRPE(_ candidates: [Session]) -> (rpe: Double?, coverage: Double, mismatch: Bool) {
    let total = Py.sum(candidates.map(\.durationMinutes))
    let rated: [(value: Double, weight: Double)] = candidates.compactMap { session in
        session.rpe.map { ($0, session.durationMinutes) }
    }
    let usable: [(value: Double, weight: Double)] = candidates.compactMap { session in
        guard !session.rpeMismatch else { return nil }
        return session.rpe.map { ($0, session.durationMinutes) }
    }
    let mismatches = candidates.filter(\.rpeMismatch).count
    let majorityMismatch = Double(mismatches) > Double(candidates.count) / 2.0
    if rated.isEmpty || total <= 0 {
        return (nil, 0.0, majorityMismatch)
    }
    if usable.isEmpty {
        // Every rating contradicts the tag: report it, but with zero coverage it never
        // moves the pace (SPEC.md §8.9, fix 9).
        return (weightedMedian(rated), 0.0, majorityMismatch)
    }
    let coverage = Py.sum(usable.map(\.weight)) / total
    return (weightedMedian(usable), coverage, majorityMismatch)
}

/// `_blend_weight` (v1.6): halving every `blendDistanceHalvingLog2` doublings from the target
/// and every `blendRecencyHalfLifeDays` of age.
func blendWeight(_ session: Session, targetDistance: Double, asOfDay: Int, config: EngineConfig) -> Double {
    let doublings = abs(log2(targetDistance / Py.max(session.effectiveDistanceM, 1e-9)))
    let ageDays = Double(Swift.max(0, asOfDay - session.day))
    return pow(0.5, doublings / config.blendDistanceHalvingLog2)
        * pow(0.5, ageDays / config.blendRecencyHalfLifeDays)
}

/// `_blended_anchor` (v1.6): every all-out piece in the tier, each turned into its own 2k
/// equivalent and averaged by `blendWeight`, returned as one synthetic anchor at the weighted
/// geometric-mean distance whose split normalises back to exactly that 2k. One piece on its own
/// is the v1.5 closest-distance anchor.
func blendedAnchor(_ candidates: [Session], tag: Tier.Name, targetDistance: Double,
                   asOfDay: Int, config: EngineConfig) -> Anchor? {
    let tier = Tier.named(tag)
    typealias Weighted = (weight: Double, session: Session)
    let pairs: [Weighted] = candidates.map { session in
        (weight: blendWeight(session, targetDistance: targetDistance, asOfDay: asOfDay, config: config),
         session: session)
    }
    // sorted(key=(weight, day), reverse=True): heaviest first, then newest; stable on ties.
    let weighted: [Weighted] = Py.stableSorted(pairs) { (lhs: Weighted, rhs: Weighted) -> Bool in
        if lhs.weight != rhs.weight { return lhs.weight > rhs.weight }
        return lhs.session.day > rhs.session.day
    }
    guard let dominant = weighted.first?.session else { return nil }
    let splitS: Double
    let distance: Double
    let method: String
    if weighted.count == 1 {
        splitS = dominant.splitS
        distance = dominant.effectiveDistanceM
        method = "closest_distance"
    } else {
        let total = Py.sum(weighted.map { (pair: Weighted) -> Double in pair.weight })
        let twoKTerms: [Double] = weighted.map { (pair: Weighted) -> Double in
            let s2k = normaliseToReference(split: pair.session.splitS,
                                           effectiveDistanceM: pair.session.effectiveDistanceM,
                                           tier: tier, config: config).s2k
            return pair.weight * s2k
        }
        let twoK = Py.sum(twoKTerms) / total
        let logTerms: [Double] = weighted.map { (pair: Weighted) -> Double in
            pair.weight * log2(pair.session.effectiveDistanceM)
        }
        distance = pow(2.0, Py.sum(logTerms) / total)
        let projection: Double = tier.paulWeight * config.paulConstant * log2(distance / tier.refDistanceM)
        splitS = twoK + projection + tier.offset
        method = "weighted_blend"
    }
    return Anchor(
        tag: tag,
        splitS: splitS,
        effectiveDistanceM: distance,
        day: dominant.day,
        date: dominant.date,
        sessionIds: weighted.map { (pair: Weighted) -> String in pair.session.id },
        method: method,
        intervalAmbiguous: dominant.intervalAmbiguous,
        rateMismatch: dominant.rateMismatch,
        rpe: dominant.rpe,
        rpeMismatch: dominant.rpeMismatch,
        declared: dominant.declared
    )
}

/// `_select_anchor`: walk tiers in rank order. Maximal tiers blend every all-out piece
/// (v1.6), or with `.closestDistance` take the single closest (then most recent); submaximal
/// tiers aggregate by duration-weighted median.
func selectAnchor(_ sessions: [Session], targetDistance: Double, config: EngineConfig,
                  asOfDay: Int? = nil) -> Anchor? {
    guard !sessions.isEmpty else { return nil }

    for tier in Tier.all {
        let candidates = sessions.filter { $0.tag == tier.name }
        if candidates.isEmpty { continue }

        if tier.isMaximal && config.maximalAnchorMethod == .blend {
            let reference = asOfDay ?? (sessions.map { (session: Session) -> Int in session.day }.max() ?? 0)
            if let anchor = blendedAnchor(candidates, tag: tier.name, targetDistance: targetDistance,
                                          asOfDay: reference, config: config) {
                return anchor
            }
            continue
        }

        if tier.isMaximal {
            // min by (|log2(target / effective)|, -day): closest distance, then most recent.
            func closeness(_ session: Session) -> (Double, Int) {
                let ratio = targetDistance / Py.max(session.effectiveDistanceM, 1e-9)
                return (abs(log2(ratio)), -session.day)
            }
            let best = Py.firstMin(candidates) { lhs, rhs in
                let a = closeness(lhs), b = closeness(rhs)
                return a.0 < b.0 || (a.0 == b.0 && a.1 < b.1)
            }
            guard let best else { continue }
            return Anchor(
                tag: tier.name,
                splitS: best.splitS,
                effectiveDistanceM: best.effectiveDistanceM,
                day: best.day,
                date: best.date,
                sessionIds: [best.id],
                method: "closest_distance",
                intervalAmbiguous: best.intervalAmbiguous,
                rateMismatch: best.rateMismatch,
                rpe: best.rpe,
                rpeMismatch: best.rpeMismatch,
                declared: best.declared
            )
        }

        if config.submaximalAnchorMethod == .singleSession {
            // max by (distance, day): longest, then most recent.
            let best = Py.firstMax(candidates) { lhs, rhs in
                lhs.distanceM < rhs.distanceM || (lhs.distanceM == rhs.distanceM && lhs.day < rhs.day)
            }
            guard let best else { continue }
            return Anchor(
                tag: tier.name,
                splitS: best.splitS,
                effectiveDistanceM: best.effectiveDistanceM,
                day: best.day,
                date: best.date,
                sessionIds: [best.id],
                method: "longest_single_session",
                intervalAmbiguous: best.intervalAmbiguous,
                rateMismatch: best.rateMismatch,
                rpe: best.rpe,
                rpeMismatch: best.rpeMismatch
            )
        }

        let split = weightedMedian(candidates.map { ($0.splitS, $0.durationMinutes) })
        let distance = weightedMedian(candidates.map { ($0.effectiveDistanceM, $0.durationMinutes) })
        let effort = tierRPE(candidates)
        guard let newest = Py.firstMax(candidates, by: { $0.day < $1.day }) else { continue }
        let rateMismatches = candidates.filter(\.rateMismatch).count
        return Anchor(
            tag: tier.name,
            splitS: split,
            effectiveDistanceM: distance,
            day: newest.day,
            date: newest.date,
            sessionIds: candidates.map(\.id),
            method: "duration_weighted_median",
            intervalAmbiguous: candidates.contains(where: \.intervalAmbiguous),
            rateMismatch: Double(rateMismatches) > Double(candidates.count) / 2.0,
            rpe: effort.rpe,
            rpeMismatch: effort.mismatch,
            rpeCoverage: effort.coverage
        )
    }

    return nil
}
