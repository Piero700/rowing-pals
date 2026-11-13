//
//  PersonalPaul.swift
//  PaceEngine
//
//  Port of `PersonalPaul` and `_personal_paul` (v1.7, SPEC.md §5.21).
//

import Foundation

/// The rower's own Paul's Law: how many seconds per 500m they slow per doubling of distance,
/// fitted to their continuous all-out pieces, or the seed when those can't show it.
struct PersonalPaul {
    let secondsPerDoubling: Double
    let fitted: Bool
    let pieces: Int
    /// Weighted spread of the pieces' distances, doublings².
    let spreadDoublings2: Double
    /// How much of the per-doubling range doubt is left (§5.13): 1 unfitted, less with evidence.
    let doubtShare: Double

    /// `_personal_paul`: weighted least squares of split on log2(distance / 2000) across the
    /// rower's continuous all-out pieces over `personalPaulWindowDays` (bests they typed in
    /// included; each halving in weight every `personalPaulHalfLifeDays`), shrunk towards the
    /// seed `paulConstant` with a prior worth `personalPaulPriorStrength` doublings² of spread,
    /// within [min, max]. Pieces at one distance only can't show a fade: the seed stands.
    static func fit(_ sessions: [Session], asOfDay: Int, config: EngineConfig) -> PersonalPaul {
        let seed = PersonalPaul(secondsPerDoubling: config.paulConstant, fitted: false, pieces: 0,
                                spreadDoublings2: 0.0, doubtShare: 1.0)
        guard config.personalPaul else { return seed }
        let pieces = sessions.filter { session in
            let age = asOfDay - session.day
            return session.tag == .an && !session.volumeOnly && session.isContinuous
                && 0 <= age && age <= config.personalPaulWindowDays
        }
        let unfitted = PersonalPaul(secondsPerDoubling: config.paulConstant, fitted: false,
                                    pieces: pieces.count, spreadDoublings2: 0.0, doubtShare: 1.0)
        guard pieces.count >= 2 else { return unfitted }

        let weights = pieces.map { pow(0.5, Double(asOfDay - $0.day) / config.personalPaulHalfLifeDays) }
        let xs = pieces.map { log2($0.effectiveDistanceM / config.referenceDistanceM) }
        let ys = pieces.map(\.splitS)
        let total = Py.sum(weights)
        let xBar = Py.sum(zip(weights, xs).map { $0 * $1 }) / total
        let yBar = Py.sum(zip(weights, ys).map { $0 * $1 }) / total
        let sxx = Py.sum(zip(weights, xs).map { w, x in w * pow(x - xBar, 2) })
        guard sxx >= 1e-6 else { return unfitted }
        let sxy = Py.sum((0..<pieces.count).map { i in weights[i] * (xs[i] - xBar) * (ys[i] - yBar) })
        let prior = config.personalPaulPriorStrength
        var slope = (sxy + prior * config.paulConstant) / (sxx + prior)
        slope = Py.max(config.personalPaulMin, Py.min(config.personalPaulMax, slope))
        return PersonalPaul(secondsPerDoubling: slope, fitted: true, pieces: pieces.count,
                            spreadDoublings2: sxx, doubtShare: (prior / (sxx + prior)).squareRoot())
    }
}
