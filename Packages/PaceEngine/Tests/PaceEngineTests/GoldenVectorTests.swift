//
//  GoldenVectorTests.swift
//  PaceEngineTests
//
//  The acceptance test for the port (HANDOFF.md, Phase 1): every case and every parsing
//  check in golden_vectors.json must reproduce the Python reference.
//

import Foundation
import Testing
@testable import PaceEngine

private let vectors = GoldenFile.shared
private let tolerance = GoldenFile.shared.tolerance.seconds

/// Numbers compare within the file's tolerance (0.02 s): Python rounds half-to-even, Swift's
/// `.rounded()` half away from zero, so exact equality is never the test.
private func expectClose(
    _ actual: Double?,
    _ expected: Double?,
    _ label: String,
    within limit: Double = tolerance,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    switch (actual, expected) {
    case (nil, nil):
        return
    case let (actual?, expected?):
        #expect(abs(actual - expected) <= limit,
                "\(label): got \(actual), expected \(expected)", sourceLocation: sourceLocation)
    default:
        Issue.record("\(label): got \(String(describing: actual)), expected \(String(describing: expected))",
                     sourceLocation: sourceLocation)
    }
}

@Suite("Golden vectors")
struct GoldenVectorTests {
    @Test("The vectors and the port share a schema version")
    func schemaVersion() {
        #expect(vectors.schemaVersion == PacePredictor.schemaVersion)
        #expect(vectors.cases.count == 38)
        let parsing = vectors.parsing
        #expect(parsing.formatSeconds.count + parsing.weightAdjustmentFactor.count
            + parsing.agePerformanceFactor.count + parsing.normaliseRPE.count == 34)
    }

    @Test("Prediction case", arguments: vectors.cases)
    func predictionCase(_ golden: GoldenCase) {
        let (config, unmapped) = GoldenSupport.config(golden.configOverrides)
        #expect(unmapped.isEmpty, "Unmapped config overrides: \(unmapped)")

        let prediction = PacePredictor.predict(
            history: GoldenSupport.sessions(golden.history),
            targetDistance: golden.targetDistanceM,
            asOf: GoldenSupport.day(golden.asOf),
            calendar: GoldenSupport.calendar,
            config: config,
            athlete: golden.athlete.map { AthleteProfile(age: $0.age, sex: $0.sex, weightKg: $0.weightKg) }
        )
        let expected = golden.expected

        // Numbers, within tolerance.
        expectClose(prediction.predictedSplitSeconds, expected.predictedSplitSeconds, "predicted_split_seconds")
        expectClose(prediction.predictedTotalTimeSeconds, expected.predictedTotalTimeSeconds,
                    "predicted_total_time_seconds")
        expectClose(prediction.load.trimpLite, expected.loadTrimpLite, "load.trimp_lite")
        expectClose(prediction.load.modifierSeconds, expected.loadModifierSeconds, "load.modifier_seconds")
        expectClose(prediction.diagnostics.spreadSeconds, expected.spreadSeconds, "diagnostics.spread_seconds")
        expectClose(prediction.interpretation?.weightAdjusted?.totalTimeSeconds,
                    expected.weightAdjustedTotalSeconds, "weight_adjusted.total_time_seconds")
        expectClose(prediction.interpretation?.ageGraded?.totalTimeSeconds,
                    expected.ageGradedTotalSeconds, "age_graded.total_time_seconds")

        // Exact.
        #expect(prediction.predictedSplitFormatted == expected.predictedSplitFormatted)
        #expect(prediction.predictedTotalTimeFormatted == expected.predictedTotalTimeFormatted)
        #expect(prediction.confidenceScore.rawValue == expected.confidenceScore)
        #expect(prediction.confidenceNumeric == expected.confidenceNumeric)
        #expect(prediction.anchor?.tier.rawValue == expected.anchorTier)
        #expect(prediction.anchor?.method == expected.anchorMethod)
        #expect(prediction.anchor?.sessionIds == expected.anchorSessionIds)

        // Flags as a set.
        #expect(Set(prediction.flags) == Set(expected.flags))

        // Components, key by key.
        let components = Dictionary(uniqueKeysWithValues: prediction.components.entries.map { ($0.key, $0.value) })
        #expect(Set(components.keys) == Set(expected.components.keys), "component keys")
        for (key, value) in expected.components {
            expectClose(components[key], value, "components.\(key)")
        }

        // Two-k equivalent by tier, key by key.
        let byTier = prediction.diagnostics.twoKEquivalentByTier
        #expect(Set(byTier.keys) == Set(expected.twoKEquivalentByTier.keys), "two_k_equivalent_by_tier keys")
        for (key, value) in expected.twoKEquivalentByTier {
            expectClose(byTier[key], value, "two_k_equivalent_by_tier.\(key)")
        }
    }

    @Test("format_seconds", arguments: vectors.parsing.formatSeconds)
    func formatSecondsCheck(_ check: Parsing.FormatCheck) {
        #expect(formatSeconds(check.input) == check.output)
    }

    @Test("weight_adjustment_factor", arguments: vectors.parsing.weightAdjustmentFactor)
    func weightFactorCheck(_ check: Parsing.WeightCheck) {
        // The vectors round these to 10 dp.
        expectClose(weightAdjustmentFactor(weightKg: check.weightKg), check.output,
                    "weight_adjustment_factor", within: 1e-9)
    }

    @Test("age_performance_factor", arguments: vectors.parsing.agePerformanceFactor)
    func ageFactorCheck(_ check: Parsing.AgeCheck) {
        expectClose(agePerformanceFactor(age: check.age), check.output, "age_performance_factor", within: 1e-9)
    }

    @Test("normalise_rpe", arguments: vectors.parsing.normaliseRPE)
    func rpeCheck(_ check: Parsing.RPECheck) {
        expectClose(normaliseRPE(check.input), check.output, "normalise_rpe", within: 1e-9)
    }
}
