//
//  EngineConfig.swift
//  PaceEngine
//
//  Port of `EngineConfig` in pace_engine.py. Every default identical to the Python.
//

import Foundation

/// All tunable behaviour. Nothing outside this type and `Tier` should need editing — and
/// any change starts in pace_engine.py, never here alone (HANDOFF.md, "Changing the engine").
public struct EngineConfig: Sendable {
    /// One knot of the volume modifier: 30-day TRIMP-lite load → seconds added to the split.
    public struct LoadKnot: Sendable, Equatable {
        public var load: Double
        public var modifierSeconds: Double

        public init(load: Double, modifierSeconds: Double) {
            self.load = load
            self.modifierSeconds = modifierSeconds
        }
    }

    /// `submaximal_anchor_method`.
    public enum SubmaximalAnchorMethod: String, Sendable {
        /// Duration-weighted median across the tier (default, robust).
        case median
        /// v1.0 parity: the longest qualifying row.
        case singleSession = "single_session"
    }

    public var windowDays: Int = 30
    /// Seconds per 500m per doubling of distance.
    public var paulConstant: Double = 5.0
    /// The latent quantity's reference distance.
    public var referenceDistanceM: Double = 2000.0

    /// Linear interpolation between knots, flat beyond the ends (SPEC.md §5.5).
    public var loadKnots: [LoadKnot] = [
        LoadKnot(load: 0.0, modifierSeconds: 3.0),
        LoadKnot(load: 600.0, modifierSeconds: 0.0),
        LoadKnot(load: 1800.0, modifierSeconds: 0.0),
        LoadKnot(load: 3600.0, modifierSeconds: -1.5),
    ]

    // Physiological sanity clamps, at the 2000m reference and scaled by Paul's Law.
    public var floorSplitAtReference: Double = 82.0
    public var ceilingSplit: Double = 210.0

    // Confidence
    public var highThreshold: Int = 75
    public var mediumThreshold: Int = 50
    public var recentAnchorDays: Int = 14
    public var staleHistoryDays: Int = 10
    public var minSessionsComfortable: Int = 6
    public var minSessionsMinimum: Int = 3
    public var tierSpreadToleranceS: Double = 6.0

    // Distance-ratio guards, in doublings.
    public var ratioWarnLog2: Double = 2.0
    public var ratioSevereLog2: Double = 3.0

    /// An AN/TR session longer than this, with no declared rep distance, is probably intervals.
    public var intervalSuspicionM: [Tier.Name: Double] = [.an: 3000.0, .tr: 10000.0]

    /// Reconciliation tolerance between a supplied split and one derived from time/distance.
    public var splitMismatchTolerance: Double = 0.02

    public var submaximalAnchorMethod: SubmaximalAnchorMethod = .median

    // Perceived effort (RPE)
    public var rpeSensitivity: Double = 1.2
    public var rpeMaxCorrection: Double = 3.0
    public var rpeContradictionPoints: Double = 2.5
    public var fatigueWindowDays: Int = 7
    public var fatigueRpeExcess: Double = 1.5

    // Bodyweight. Concept2: Wf = (lbs / 270) ^ 0.222.
    public var weightAdjustExponent: Double = 0.222
    public var weightAdjustReferenceLb: Double = 270.0
    /// Off by default: one athlete's weight change is not two athletes' difference.
    public var weightTrendSensitivity: Double = 0.0
    public var weightTrendMinKg: Double = 1.5

    // Cold-start population prior. SEED VALUES, not fitted (SPEC.md §7.6).
    public var priorReferenceAge: Double = 27.0
    public var priorMale2kSeconds: Double = 440.0
    public var priorFemale2kSeconds: Double = 500.0
    public var priorMaleReferenceKg: Double = 82.0
    public var priorFemaleReferenceKg: Double = 68.0
    public var priorConfidenceNumeric: Int = 15

    /// Reproduce the original v1.0 Step 3 arithmetic, for A/B measurement only.
    public var legacyV1Formula: Bool = false

    public init() {}

    public static let `default` = EngineConfig()
}
