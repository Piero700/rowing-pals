//
//  PredictionRange.swift
//  PaceEngine
//
//  Port of `_prediction_range` (SPEC.md §5.13, engine v1.5).
//

import Foundation

/// Half-width of the likely range around the predicted split, seconds per 500m: one term per
/// independent reason the number could be off, added in quadrature. A maximal anchor projects
/// from its own distance; a submaximal one has already been converted to the 2000m reference
/// (its doubt is in the zone's base term), so it projects from there.
func predictionRange(
    anchor: Anchor,
    targetDistance: Double,
    spreadS: Double,
    tiersRepresented: Int,
    loadConfidence: Double,
    asOfDay: Int,
    config: EngineConfig,
    paulDoubtShare: Double = 1.0,
    steadyTracked: Bool = false,
    steadyGain: Double = 0.0,
    volumeGain: Double = 0.0
) -> Double {
    // v1.7: a steady-zone blend's base is weighted across its zones; a fitted personal Paul's
    // Law leaves less doubt per doubling; steady rows measured since a stale test shrink its
    // staleness doubt; each nudge that makes the prediction faster carries part of itself.
    let daysAgo = asOfDay - anchor.day
    let projectionFrom = anchor.tier.isMaximal ? anchor.effectiveDistanceM : config.referenceDistanceM
    let doublings = abs(log2(targetDistance / Py.max(projectionFrom, 1e-9)))
    var stale = Double(Swift.max(0, daysAgo - config.recentAnchorDays)) * config.rangePerStaleDayS
    if steadyTracked {
        stale *= config.rangeStaleShareWhenTracked
    }
    let terms: [Double] = [
        anchor.rangeBase ?? config.rangeBaseSplitS[anchor.tag] ?? 0.0,
        stale,
        doublings * config.rangePerDoublingS * paulDoubtShare,
        config.rangeGainShare * abs(steadyGain),
        config.rangeGainShare * abs(Py.min(0.0, volumeGain)),
        tiersRepresented >= 2 ? spreadS * config.rangeSpreadShare : 0.0,
        (1.0 - loadConfidence) * config.rangeThinHistoryS,
        anchor.intervalAmbiguous ? config.rangeIntervalAmbiguousS : 0.0,
        anchor.rateMismatch ? config.rangeTagMismatchS : 0.0,
        anchor.rpeMismatch ? config.rangeTagMismatchS : 0.0,
    ]
    return terms.map { $0 * $0 }.reduce(0.0, +).squareRoot()
}
