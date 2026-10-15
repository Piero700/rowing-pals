//
//  GoldenVectors.swift
//  PaceEngineTests
//
//  Decodes golden_vectors.json — generated from PaceEngine/pace_engine.py by
//  make_golden_vectors.py and copied here unchanged.
//

import Foundation
import Testing
@testable import PaceEngine

struct GoldenFile: Decodable, Sendable {
    struct Tolerance: Decodable, Sendable {
        let seconds: Double
    }

    let schemaVersion: String
    let tolerance: Tolerance
    let cases: [GoldenCase]
    let parsing: Parsing

    enum CodingKeys: String, CodingKey {
        case tolerance, cases, parsing
        case schemaVersion = "schema_version"
    }

    static let shared: GoldenFile = {
        let url = Bundle.module.url(forResource: "golden_vectors", withExtension: "json")
            ?? Bundle.module.url(forResource: "golden_vectors", withExtension: "json", subdirectory: "Resources")
        let data = try! Data(contentsOf: url!)
        return try! JSONDecoder().decode(GoldenFile.self, from: data)
    }()
}

struct GoldenCase: Decodable, Sendable, CustomTestStringConvertible {
    struct Row: Decodable, Sendable {
        let id: String
        let date: String
        let distanceM: Double
        let timeS: Double?
        let splitS: Double?
        let strokeRate: Double?
        let tag: String
        let repDistanceM: Double?
        let rpe: Double?
        let bodyweightKg: Double?
        let declared: Bool?

        enum CodingKeys: String, CodingKey {
            case id, date, tag, rpe, declared
            case distanceM = "distance_m"
            case timeS = "time_s"
            case splitS = "split_s"
            case strokeRate = "stroke_rate"
            case repDistanceM = "rep_distance_m"
            case bodyweightKg = "bodyweight_kg"
        }
    }

    struct Athlete: Decodable, Sendable {
        let age: Double?
        let sex: String?
        let weightKg: Double?

        enum CodingKeys: String, CodingKey {
            case age, sex
            case weightKg = "weight_kg"
        }
    }

    struct Expected: Decodable, Sendable {
        let predictedSplitSeconds: Double?
        let predictedTotalTimeSeconds: Double?
        let predictedSplitFormatted: String?
        let predictedTotalTimeFormatted: String?
        let predictedSplitRangeSeconds: Double?
        let predictedTotalTimeRangeSeconds: Double?
        let confidenceScore: String
        let confidenceNumeric: Int
        let anchorTier: String?
        let anchorMethod: String?
        let anchorSessionIds: [String]?
        let components: [String: Double]
        let loadTrimpLite: Double
        let loadModifierSeconds: Double
        let spreadSeconds: Double
        let twoKEquivalentByTier: [String: Double]
        let weightAdjustedTotalSeconds: Double?
        let ageGradedTotalSeconds: Double?
        let flags: [String]

        enum CodingKeys: String, CodingKey {
            case components, flags
            case predictedSplitSeconds = "predicted_split_seconds"
            case predictedTotalTimeSeconds = "predicted_total_time_seconds"
            case predictedSplitFormatted = "predicted_split_formatted"
            case predictedTotalTimeFormatted = "predicted_total_time_formatted"
            case predictedSplitRangeSeconds = "predicted_split_range_seconds"
            case predictedTotalTimeRangeSeconds = "predicted_total_time_range_seconds"
            case confidenceScore = "confidence_score"
            case confidenceNumeric = "confidence_numeric"
            case anchorTier = "anchor_tier"
            case anchorMethod = "anchor_method"
            case anchorSessionIds = "anchor_session_ids"
            case loadTrimpLite = "load_trimp_lite"
            case loadModifierSeconds = "load_modifier_seconds"
            case spreadSeconds = "spread_seconds"
            case twoKEquivalentByTier = "two_k_equivalent_by_tier"
            case weightAdjustedTotalSeconds = "weight_adjusted_total_seconds"
            case ageGradedTotalSeconds = "age_graded_total_seconds"
        }
    }

    let name: String
    let asOf: String
    let targetDistanceM: Double
    let configOverrides: [String: OverrideValue]
    let athlete: Athlete?
    let history: [Row]
    let expected: Expected

    var testDescription: String { name }

    enum CodingKeys: String, CodingKey {
        case name, athlete, history, expected
        case asOf = "as_of"
        case targetDistanceM = "target_distance_m"
        case configOverrides = "config_overrides"
    }
}

/// A `config_overrides` value: a number, a switch or a choice, as Python wrote it.
enum OverrideValue: Decodable, Sendable {
    case number(Double)
    case flag(Bool)
    case text(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let flag = try? container.decode(Bool.self) {
            self = .flag(flag)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            self = .text(try container.decode(String.self))
        }
    }

    var number: Double? { if case .number(let value) = self { value } else { nil } }
    var flag: Bool? { if case .flag(let value) = self { value } else { nil } }
    var text: String? { if case .text(let value) = self { value } else { nil } }
}

struct Parsing: Decodable, Sendable {
    struct FormatCheck: Decodable, Sendable, CustomTestStringConvertible {
        let input: Double
        let output: String?
        var testDescription: String { "format_seconds(\(input))" }
        enum CodingKeys: String, CodingKey { case input = "in", output = "out" }
    }

    struct WeightCheck: Decodable, Sendable, CustomTestStringConvertible {
        let weightKg: Double
        let output: Double
        var testDescription: String { "weight_adjustment_factor(\(weightKg))" }
        enum CodingKeys: String, CodingKey { case weightKg = "weight_kg", output = "out" }
    }

    struct AgeCheck: Decodable, Sendable, CustomTestStringConvertible {
        let age: Double
        let output: Double
        var testDescription: String { "age_performance_factor(\(age))" }
        enum CodingKeys: String, CodingKey { case age, output = "out" }
    }

    struct RPECheck: Decodable, Sendable, CustomTestStringConvertible {
        let input: Double
        let output: Double?
        var testDescription: String { "normalise_rpe(\(input))" }
        enum CodingKeys: String, CodingKey { case input = "in", output = "out" }
    }

    struct ZoneTargetCheck: Decodable, Sendable, CustomTestStringConvertible {
        let s2k: Double
        let tag: String
        let distanceM: Double
        let output: Double
        var testDescription: String { "zone_target_split(\(s2k), \(tag), \(distanceM))" }
        enum CodingKeys: String, CodingKey { case s2k, tag, distanceM = "distance_m", output = "out" }
    }

    let formatSeconds: [FormatCheck]
    let weightAdjustmentFactor: [WeightCheck]
    let agePerformanceFactor: [AgeCheck]
    let normaliseRPE: [RPECheck]
    let zoneTargetSplit: [ZoneTargetCheck]

    enum CodingKeys: String, CodingKey {
        case formatSeconds = "format_seconds"
        case weightAdjustmentFactor = "weight_adjustment_factor"
        case agePerformanceFactor = "age_performance_factor"
        case normaliseRPE = "normalise_rpe"
        case zoneTargetSplit = "zone_target_split"
    }
}

enum GoldenSupport {
    /// A fixed UTC calendar, so the tests don't depend on the machine's time zone.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// "YYYY-MM-DD" as that calendar day.
    static func day(_ text: String) -> Date {
        let parts = text.split(separator: "-").map { Int($0)! }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
    }

    /// `config_overrides` uses the Python snake_case names; each is mapped explicitly.
    static func config(_ overrides: [String: OverrideValue]) -> (EngineConfig, unmapped: [String]) {
        var config = EngineConfig.default
        var unmapped: [String] = []
        for (key, override) in overrides {
            if key == "maximal_anchor_method", let text = override.text,
               let method = EngineConfig.MaximalAnchorMethod(rawValue: text) {
                config.maximalAnchorMethod = method
                continue
            }
            if key == "held_split_floor", let flag = override.flag {
                config.heldSplitFloor = flag
                continue
            }
            guard let value = override.number else {
                unmapped.append(key)
                continue
            }
            switch key {
            case "rpe_sensitivity": config.rpeSensitivity = value
            case "rpe_max_correction": config.rpeMaxCorrection = value
            case "rpe_contradiction_points": config.rpeContradictionPoints = value
            case "weight_trend_sensitivity": config.weightTrendSensitivity = value
            case "weight_trend_min_kg": config.weightTrendMinKg = value
            case "window_days": config.windowDays = Int(value)
            case "paul_constant": config.paulConstant = value
            case "tier_spread_tolerance_s": config.tierSpreadToleranceS = value
            case "split_mismatch_tolerance": config.splitMismatchTolerance = value
            default: unmapped.append(key)
            }
        }
        return (config, unmapped)
    }

    static func sessions(_ rows: [GoldenCase.Row]) -> [SessionInput] {
        rows.map { row in
            SessionInput(
                id: row.id,
                date: day(row.date),
                distanceM: row.distanceM,
                tag: Tier.Name(rawValue: row.tag)!,
                timeS: row.timeS,
                splitS: row.splitS,
                strokeRate: row.strokeRate,
                repDistanceM: row.repDistanceM,
                rpe: row.rpe,
                bodyweightKg: row.bodyweightKg,
                declared: row.declared ?? false
            )
        }
    }
}
