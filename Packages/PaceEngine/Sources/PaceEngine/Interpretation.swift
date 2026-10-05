//
//  Interpretation.swift
//  PaceEngine
//
//  Port of `_interpretation`: comparable scores DERIVED from the prediction, never fed back
//  into it (SPEC.md §2.1).
//

import Foundation

func interpretation(
    split: Double,
    targetDistance: Double,
    athlete: Athlete,
    config: EngineConfig
) -> Prediction.Interpretation {
    let total = split * targetDistance / 500.0
    var block = Prediction.Interpretation(weightAdjusted: nil, ageGraded: nil, notes: [])

    if let weight = athlete.weightKg, let factor = weightAdjustmentFactor(weightKg: weight, config: config) {
        let adjusted = total * factor
        block.weightAdjusted = .init(
            factor: Py.round(factor, 4),
            totalTimeSeconds: Py.round(adjusted, 2),
            totalTimeFormatted: formatSeconds(adjusted),
            splitFormatted: formatSeconds(adjusted / targetDistance * 500.0),
            method: "Concept2: Wf = (lbs / 270) ^ 0.222"
        )
    }

    if let age = athlete.age {
        let factor = agePerformanceFactor(age: age, config: config)
        let graded = total / factor
        block.ageGraded = .init(
            factor: Py.round(factor, 4),
            referenceAge: config.priorReferenceAge,
            totalTimeSeconds: Py.round(graded, 2),
            totalTimeFormatted: formatSeconds(graded),
            splitFormatted: formatSeconds(graded / targetDistance * 500.0),
            method: "fitted to Concept2 rankings medians (2025-26), not an official standard"
        )
        block.notes.append(
            "Age grading follows the median ranked 2k at each age, from rowers who chose "
                + "to log a ranked result. Treat it as indicative, not an official standard."
        )
    }

    return block
}
