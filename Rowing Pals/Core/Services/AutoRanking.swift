//
//  AutoRanking.swift
//  Rowing Pals
//

import Foundation

/// Which results a posted session puts on the test leaderboards (decision 104). Any photographed
/// Main or Extra piece at a test's distance or time counts, whatever its rate or zone, and so does
/// every rep of an interval workout: the best of a 10 × 500m goes on the 500m board. Warm-ups and
/// cool-downs never count, and nor does an interval workout's total (10 × 500m is not a 5k).
/// One result per test per session, the session's best. Whether it's a new PB is judged against
/// the rower's earlier results by the caller.
///
/// The database's one-off `backfill_test_results()` applies the same rules to posts made before
/// this (docs/migrations/2026-11-13-automatic-leaderboards.sql); keep the two in step.
nonisolated enum AutoRanking {
    /// One photographed piece as posted.
    struct Piece {
        let segmentId: UUID
        let label: SegmentLabel
        /// The whole piece, used when it isn't an interval workout.
        let distanceM: Int
        let timeMs: Int
        let isInterval: Bool
        /// Each rep read off the monitor (interval workouts only).
        let reps: [(distanceM: Int, timeMs: Int)]
    }

    /// A result for one test, ready for `test_results`.
    struct Result: Equatable {
        let key: String
        let segmentId: UUID
        let distanceM: Int
        let timeMs: Int

        /// Per 500 m, from distance and time, as everywhere else in the app.
        var splitMs: Int {
            guard distanceM > 0 else { return 0 }
            return Int((Double(timeMs) / (Double(distanceM) / 500)).rounded())
        }
    }

    /// The session's best result for every test any of its pieces or reps meets. `tests` is the
    /// standard tests plus the rower's club tests.
    static func results(for pieces: [Piece], tests: [StandardTest]) -> [Result] {
        var best: [String: Result] = [:]
        for piece in pieces where piece.label == .main || piece.label == .extra {
            let efforts = piece.isInterval ? piece.reps : [(piece.distanceM, piece.timeMs)]
            for effort in efforts where effort.distanceM > 0 && effort.timeMs > 0 {
                for test in tests where test.accepts(distanceM: effort.distanceM, timeMs: effort.timeMs) {
                    let candidate = Result(key: test.key, segmentId: piece.segmentId,
                                           distanceM: effort.distanceM, timeMs: effort.timeMs)
                    if let current = best[test.key], !isBetter(candidate, than: current, test: test) { continue }
                    best[test.key] = candidate
                }
            }
        }
        // In the order the tests are listed, so posting is predictable.
        return tests.compactMap { best[$0.key] }
    }

    /// Faster for a distance test; further for a timed one.
    static func isBetter(_ result: Result, than other: Result, test: StandardTest) -> Bool {
        test.isDurationBased ? result.distanceM > other.distanceM : result.timeMs < other.timeMs
    }

    /// Whether a result beats every earlier result for its test. The first result for a test is a PB.
    static func isNewBest(_ result: Result, test: StandardTest, previous: [(distanceM: Int, timeMs: Int)]) -> Bool {
        guard !previous.isEmpty else { return true }
        if test.isDurationBased {
            return result.distanceM > previous.map(\.distanceM).max() ?? 0
        }
        return result.timeMs < previous.map(\.timeMs).min() ?? Int.max
    }
}
