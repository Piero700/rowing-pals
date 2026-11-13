//
//  Prediction.swift
//  PaceEngine
//
//  The engine's output, mirroring SPEC.md §6. Codable with the same snake_case keys the
//  Python dict uses; a key the Python sets to null is omitted here.
//

import Foundation

public struct Prediction: Codable, Sendable, Equatable {
    /// `confidence_score`. The app keys UI off these exact strings.
    public enum ConfidenceBand: String, Codable, Sendable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case populationEstimate = "Population Estimate"
        case insufficientData = "Insufficient Data"
    }

    public struct ConfidenceFactor: Codable, Sendable, Equatable {
        public var label: String
        public var delta: Int
    }

    public struct AnchorSummary: Codable, Sendable, Equatable {
        public var tier: Tier.Name
        public var sessionIds: [String]
        public var date: String
        public var daysAgo: Int
        public var splitSeconds: Double
        public var splitFormatted: String?
        public var effectiveDistanceM: Double
        public var method: String
        public var rpe: Double?
        /// v1.6: the piece that weighs most is a best the rower typed in.
        public var declared: Bool?

        enum CodingKeys: String, CodingKey {
            case tier, date, method, rpe, declared
            case sessionIds = "session_ids"
            case daysAgo = "days_ago"
            case splitSeconds = "split_seconds"
            case splitFormatted = "split_formatted"
            case effectiveDistanceM = "effective_distance_m"
        }
    }

    public struct Load: Codable, Sendable, Equatable {
        public var trimpLite: Double
        public var sessionCount: Int
        public var windowDays: Int
        public var rawModifierSeconds: Double
        public var loadConfidence: Double
        /// v1.7 (§5.20): the share of a faster modifier that applies — training after the newest
        /// all-out piece; 0 when a measured steady change replaces it.
        public var afterMeasurementShare: Double
        public var modifierSeconds: Double

        enum CodingKeys: String, CodingKey {
            case trimpLite = "trimp_lite"
            case sessionCount = "session_count"
            case windowDays = "window_days"
            case rawModifierSeconds = "raw_modifier_seconds"
            case loadConfidence = "load_confidence"
            case afterMeasurementShare = "after_measurement_share"
            case modifierSeconds = "modifier_seconds"
        }

        static func empty(windowDays: Int) -> Load {
            Load(trimpLite: 0.0, sessionCount: 0, windowDays: windowDays, rawModifierSeconds: 0.0,
                 loadConfidence: 0.0, afterMeasurementShare: 0.0, modifierSeconds: 0.0)
        }
    }

    /// v1.7 (§5.21): the rower's own Paul's Law, or the seed 5.0 when their all-out pieces
    /// can't show one.
    public struct PersonalPaulSummary: Codable, Sendable, Equatable {
        public var secondsPerDoubling: Double
        public var fitted: Bool
        public var pieces: Int

        enum CodingKeys: String, CodingKey {
            case fitted, pieces
            case secondsPerDoubling = "seconds_per_doubling"
        }
    }

    /// v1.7 (§5.19): steady rows since the newest all-out piece.
    public struct SteadySummary: Codable, Sendable, Equatable {
        /// After minus before, 2k-equivalent seconds per 500m (negative = faster).
        public var changeSeconds: Double
        /// The share of it that carries to the target.
        public var transfer: Double
        public var piecesBefore: Int
        public var piecesAfter: Int
        public var zones: [Tier.Name]
        public var measuredOn: String?

        enum CodingKeys: String, CodingKey {
            case transfer, zones
            case changeSeconds = "change_seconds"
            case piecesBefore = "pieces_before"
            case piecesAfter = "pieces_after"
            case measuredOn = "measured_on"
        }
    }

    /// Reads top to bottom as the arithmetic: anchor + paul + offset + rpe + rate = 2k
    /// equivalent; then + projection + weight + steady + volume + held + clamp = predicted
    /// split. A population estimate fills only the population, 2k-equivalent and projection lines.
    public struct Components: Codable, Sendable, Equatable {
        public var anchorSplit: Double?
        public var paulAdjustment: Double?
        public var intensityOffset: Double?
        public var rpeCorrection: Double?
        /// v1.7 (§5.18): a steady anchor piece's rate, read back to its zone's usual rate.
        public var rateCorrection: Double?
        public var twoKEquivalent: Double?
        public var projectionToTarget: Double?
        public var weightTrendCorrection: Double?
        /// v1.7 (§5.19): steady rows since the newest all-out piece; never positive.
        public var steadyChangeAdjustment: Double?
        public var volumeModifier: Double?
        /// v1.6: how far the split was brought down to one already held for longer (§5.15).
        public var heldSplitAdjustment: Double?
        public var clampAdjustment: Double?
        public var population2kSeconds: Double?

        enum CodingKeys: String, CodingKey, CaseIterable {
            case anchorSplit = "anchor_split"
            case paulAdjustment = "paul_adjustment"
            case intensityOffset = "intensity_offset"
            case rpeCorrection = "rpe_correction"
            case rateCorrection = "rate_correction"
            case twoKEquivalent = "two_k_equivalent"
            case projectionToTarget = "projection_to_target"
            case weightTrendCorrection = "weight_trend_correction"
            case steadyChangeAdjustment = "steady_change_adjustment"
            case volumeModifier = "volume_modifier"
            case heldSplitAdjustment = "held_split_adjustment"
            case clampAdjustment = "clamp_adjustment"
            case population2kSeconds = "population_2k_seconds"
        }

        /// The lines present, in arithmetic order, keyed by their output names.
        public var entries: [(key: String, value: Double)] {
            let values: [Double?] = [anchorSplit, paulAdjustment, intensityOffset, rpeCorrection,
                                     rateCorrection, twoKEquivalent, projectionToTarget,
                                     weightTrendCorrection, steadyChangeAdjustment,
                                     volumeModifier, heldSplitAdjustment, clampAdjustment, population2kSeconds]
            return zip(CodingKeys.allCases, values).compactMap { key, value in
                value.map { (key.rawValue, $0) }
            }
        }
    }

    public struct Effort: Codable, Sendable, Equatable {
        public var sessionsWithRpe: Int
        public var anchorRpe: Double?
        public var recentRpeExcess: Double?

        enum CodingKeys: String, CodingKey {
            case sessionsWithRpe = "sessions_with_rpe"
            case anchorRpe = "anchor_rpe"
            case recentRpeExcess = "recent_rpe_excess"
        }
    }

    public struct AthleteSummary: Codable, Sendable, Equatable {
        public var age: Double?
        public var sex: String?
        public var weightKg: Double?
        public var bodyweightAtAnchorKg: Double?
        /// False unless the weight-trend term fired: age and sex never shape the number.
        public var usedInPrediction: Bool

        enum CodingKeys: String, CodingKey {
            case age, sex
            case weightKg = "weight_kg"
            case bodyweightAtAnchorKg = "bodyweight_at_anchor_kg"
            case usedInPrediction = "used_in_prediction"
        }
    }

    public struct Interpretation: Codable, Sendable, Equatable {
        public struct WeightAdjusted: Codable, Sendable, Equatable {
            public var factor: Double
            public var totalTimeSeconds: Double
            public var totalTimeFormatted: String?
            public var splitFormatted: String?
            public var method: String

            enum CodingKeys: String, CodingKey {
                case factor, method
                case totalTimeSeconds = "total_time_seconds"
                case totalTimeFormatted = "total_time_formatted"
                case splitFormatted = "split_formatted"
            }
        }

        public struct AgeGraded: Codable, Sendable, Equatable {
            public var factor: Double
            public var referenceAge: Double
            public var totalTimeSeconds: Double
            public var totalTimeFormatted: String?
            public var splitFormatted: String?
            public var method: String

            enum CodingKeys: String, CodingKey {
                case factor, method
                case referenceAge = "reference_age"
                case totalTimeSeconds = "total_time_seconds"
                case totalTimeFormatted = "total_time_formatted"
                case splitFormatted = "split_formatted"
            }
        }

        /// A weight-class comparison: not for leaderboards or public views without sign-off.
        public var weightAdjusted: WeightAdjusted?
        /// Seed curve: indicative only.
        public var ageGraded: AgeGraded?
        public var notes: [String]

        enum CodingKeys: String, CodingKey {
            case notes
            case weightAdjusted = "weight_adjusted"
            case ageGraded = "age_graded"
        }
    }

    public struct Diagnostics: Codable, Sendable, Equatable {
        public var twoKEquivalentByTier: [String: Double]
        public var twoKEquivalentFormatted: [String: String]?
        public var spreadSeconds: Double
        public var tiersRepresented: Int
        public var warnings: [String]

        enum CodingKeys: String, CodingKey {
            case warnings
            case twoKEquivalentByTier = "two_k_equivalent_by_tier"
            case twoKEquivalentFormatted = "two_k_equivalent_formatted"
            case spreadSeconds = "spread_seconds"
            case tiersRepresented = "tiers_represented"
        }

        static let empty = Diagnostics(twoKEquivalentByTier: [:], twoKEquivalentFormatted: nil,
                                       spreadSeconds: 0.0, tiersRepresented: 0, warnings: [])
    }

    public var schemaVersion: String
    public var generatedForDate: String?
    public var targetDistanceM: Double?
    public var predictedSplitSeconds: Double?
    public var predictedSplitFormatted: String?
    public var predictedTotalTimeSeconds: Double?
    public var predictedTotalTimeFormatted: String?
    /// ± around the predicted split and total time, seconds (SPEC.md §5.13, v1.5); nil for a
    /// population estimate or no prediction.
    public var predictedSplitRangeSeconds: Double?
    public var predictedTotalTimeRangeSeconds: Double?
    public var confidenceScore: ConfidenceBand
    public var confidenceNumeric: Int
    public var confidenceFactors: [ConfidenceFactor]
    public var anchor: AnchorSummary?
    public var load: Load
    /// v1.7: nil for a population estimate or no prediction.
    public var personalPaul: PersonalPaulSummary?
    /// v1.7: nil when steady rows since the newest all-out piece weren't measured.
    public var steady: SteadySummary?
    public var components: Components
    /// Population estimates only: how each adjustment was made.
    public var estimateBasis: [String]?
    public var effort: Effort
    public var athlete: AthleteSummary?
    public var interpretation: Interpretation?
    public var diagnostics: Diagnostics
    /// API: the app keys UI off these exact spellings.
    public var flags: [String]
    public var warnings: [String]
    public var recommendations: [String]

    enum CodingKeys: String, CodingKey {
        case anchor, load, steady, components, effort, athlete, interpretation, diagnostics, flags,
             warnings, recommendations
        case personalPaul = "personal_paul"
        case schemaVersion = "schema_version"
        case generatedForDate = "generated_for_date"
        case targetDistanceM = "target_distance_m"
        case predictedSplitSeconds = "predicted_split_seconds"
        case predictedSplitFormatted = "predicted_split_formatted"
        case predictedTotalTimeSeconds = "predicted_total_time_seconds"
        case predictedTotalTimeFormatted = "predicted_total_time_formatted"
        case predictedSplitRangeSeconds = "predicted_split_range_seconds"
        case predictedTotalTimeRangeSeconds = "predicted_total_time_range_seconds"
        case confidenceScore = "confidence_score"
        case confidenceNumeric = "confidence_numeric"
        case confidenceFactors = "confidence_factors"
        case estimateBasis = "estimate_basis"
    }
}
