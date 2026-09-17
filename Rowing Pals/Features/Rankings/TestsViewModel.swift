//
//  TestsViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns the distance picker's own-PB lookups — one per standard distance,
/// so the grid doubles as a personal scoreboard (design brief, Screen 6A).
@Observable
final class TestsViewModel {
    struct Tile: Identifiable {
        let test: StandardTest
        /// nil shows a quiet "—" — no result for this distance yet.
        let displayValue: String?
        var id: String { test.key }
    }

    var tiles: [Tile] = StandardTest.all.map { Tile(test: $0, displayValue: nil) }
    var isLoading = false

    @MainActor
    func loadOwnPBs() async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = try? await SupabaseService.shared.auth.session.user.id else { return }

        struct ResultRow: Decodable {
            let distanceKey: String
            let distanceM: Int
            let timeMs: Int

            enum CodingKeys: String, CodingKey {
                case distanceKey = "distance_key"
                case distanceM = "distance_m"
                case timeMs = "time_ms"
            }
        }

        guard let rows: [ResultRow] = try? await SupabaseService.shared
            .from("test_results")
            .select("distance_key, distance_m, time_ms")
            .eq("user_id", value: userId)
            .execute()
            .value
        else { return }

        var bestByKey: [String: ResultRow] = [:]
        for row in rows {
            guard let test = StandardTest.all.first(where: { $0.key == row.distanceKey }) else { continue }
            guard let existing = bestByKey[row.distanceKey] else {
                bestByKey[row.distanceKey] = row
                continue
            }
            let isBetter = test.isDurationBased ? row.distanceM > existing.distanceM : row.timeMs < existing.timeMs
            if isBetter { bestByKey[row.distanceKey] = row }
        }

        tiles = StandardTest.all.map { test in
            guard let row = bestByKey[test.key] else { return Tile(test: test, displayValue: nil) }
            let display = test.isDurationBased ? "\(row.distanceM.formattedWithGrouping)m" : row.timeMs.formattedDurationMs
            return Tile(test: test, displayValue: display)
        }
    }
}
