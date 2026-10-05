//
//  ClubTest.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `club_tests` table (docs/migrations/2026-10-04-club-tests.sql, decision 28): a
/// test a club's admins added next to the nine standard ones — a distance (750m, 3k) or a whole
/// number of minutes (20min). Its results are ordinary `test_results` rows keyed by `key`.
nonisolated struct ClubTest: Codable, Identifiable, Hashable {
    let id: UUID
    let clubId: UUID
    let label: String
    let distanceM: Int?
    let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case id, label
        case clubId = "club_id"
        case distanceM = "distance_m"
        case durationMs = "duration_ms"
    }

    /// Starts every club test's `test_results.distance_key`.
    static let keyPrefix = "club:"

    /// `test_results.distance_key` for this test: "club:" and the id as Postgres writes it
    /// (lower case), so the database's own clean-up on delete finds the same rows.
    var key: String { Self.keyPrefix + id.uuidString.lowercased() }

    /// This test in the shape the review screen and the leaderboards already take, so a club
    /// test is chosen, checked, posted and ranked exactly like a standard one.
    var asTest: StandardTest {
        let target: StandardTest.Target = durationMs.map { .duration(ms: $0) } ?? .distance(m: distanceM ?? 0)
        return StandardTest(key: key, label: label, target: target)
    }

    // MARK: - Adding one

    /// The limits `create_club_test` enforces.
    static let distanceRange = 100...100_000
    static let minutesRange = 1...120

    /// "750m", "3k", "20min" — the same rule as the database's `club_test_label`, shown while
    /// an admin types.
    static func label(distanceM: Int?, minutes: Int?) -> String? {
        if let distanceM {
            return distanceM % 1000 == 0 ? "\(distanceM / 1000)k" : "\(distanceM)m"
        }
        return minutes.map { "\($0)min" }
    }

    /// Why a new test can't be added, or nil if it can. The database checks the same things;
    /// this says so before the admin presses Add.
    static func problem(distanceM: Int?, minutes: Int?, existing: [ClubTest]) -> String? {
        if let distanceM {
            guard distanceRange.contains(distanceM) else {
                return "A distance test must be between 100m and 100,000m."
            }
        } else if let minutes {
            guard minutesRange.contains(minutes) else {
                return "A timed test must be from 1 to 120 minutes."
            }
        } else {
            return "Enter a distance or a time."
        }
        let standard = StandardTest.all.contains { test in
            switch test.target {
            case .distance(let m): m == distanceM
            case .duration(let ms): ms == minutes.map { $0 * 60_000 }
            }
        }
        if standard { return "That's already a standard test." }
        guard let label = label(distanceM: distanceM, minutes: minutes) else { return nil }
        if existing.contains(where: { $0.label.lowercased() == label.lowercased() }) {
            return "Your club already has a \(label) test."
        }
        return nil
    }

    /// Distance tests shortest first, then timed tests shortest first — the standard grid's order.
    static func sorted(_ tests: [ClubTest]) -> [ClubTest] {
        tests.sorted { lhs, rhs in
            switch (lhs.distanceM, rhs.distanceM) {
            case let (l?, r?): l < r
            case (.some, nil): true
            case (nil, .some): false
            case (nil, nil): (lhs.durationMs ?? 0) < (rhs.durationMs ?? 0)
            }
        }
    }
}
