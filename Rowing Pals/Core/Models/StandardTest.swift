//
//  StandardTest.swift
//  Rowing Pals
//

import Foundation

/// The nine standard test distances/times — 500m, 1k, 2k, 5k, 6k, 10k, or a
/// 4min/30min/60min time piece — that a Main segment can match. Shared
/// between the review sheet's test-detection prompt (task 11, matches a
/// segment against this list) and the test leaderboards' distance picker
/// (task 14, shows one tile per entry) — the two need the exact same
/// catalog, not two copies of it.
nonisolated struct StandardTest: Identifiable, Equatable {
    /// '500m','1k','2k','5k','6k','10k','4min','30min','60min' — matches
    /// `test_results.distance_key` in docs/schema.sql exactly.
    let key: String
    let label: String

    enum Target: Equatable {
        case distance(m: Int)
        case duration(ms: Int)
    }

    let target: Target

    var id: String { key }

    static let all: [StandardTest] = [
        StandardTest(key: "500m", label: "500m", target: .distance(m: 500)),
        StandardTest(key: "1k", label: "1k", target: .distance(m: 1000)),
        StandardTest(key: "2k", label: "2k", target: .distance(m: 2000)),
        StandardTest(key: "5k", label: "5k", target: .distance(m: 5000)),
        StandardTest(key: "6k", label: "6k", target: .distance(m: 6000)),
        StandardTest(key: "10k", label: "10k", target: .distance(m: 10000)),
        StandardTest(key: "4min", label: "4min", target: .duration(ms: 4 * 60 * 1000)),
        StandardTest(key: "30min", label: "30min", target: .duration(ms: 30 * 60 * 1000)),
        StandardTest(key: "60min", label: "60min", target: .duration(ms: 60 * 60 * 1000))
    ]

    /// Finds the standard test a segment's distance/time matches, within a
    /// tolerance — a PM5 piece programmed as "2k" stops exactly at 2000m,
    /// so this mainly absorbs a stray metre of finish-line rounding or an
    /// OCR misread, not real variation. 1% of the target, floored so short
    /// distances/times still get a sane minimum.
    static func match(distanceM: Int, timeMs: Int) -> StandardTest? {
        all.first { test in
            switch test.target {
            case .distance(let target):
                let tolerance = max(5, Int(Double(target) * 0.01))
                return abs(distanceM - target) <= tolerance
            case .duration(let target):
                let tolerance = max(2000, Int(Double(target) * 0.01))
                return abs(timeMs - target) <= tolerance
            }
        }
    }
}
