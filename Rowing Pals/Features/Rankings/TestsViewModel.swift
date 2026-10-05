//
//  TestsViewModel.swift
//  Rowing Pals
//

import Foundation
import PaceEngine
import Supabase

/// Owns the distance picker's own-PB lookups — one per standard distance, then one per club
/// test (decision 28) — so the grid doubles as a personal scoreboard (design brief, Screen 6A).
@Observable
final class TestsViewModel {
    struct Tile: Identifiable {
        let test: StandardTest
        /// Set for a club test, which admins and up can delete from its board.
        var clubTest: ClubTest?
        /// nil shows a quiet "—" — no result for this distance yet.
        let displayValue: String?
        /// Your predicted time for a distance test (decision 31); nil for a timed test, or
        /// when there isn't enough data for a prediction.
        var predicted: String?
        var id: String { test.key }
    }

    var tiles: [Tile] = StandardTest.all.map { Tile(test: $0, displayValue: nil) }
    /// The rower's club tests, and whether they may add or delete them.
    var clubTests = ClubTestService.MyClubTests.none
    var isLoading = false

    @MainActor
    func loadOwnPBs() async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = try? await SupabaseService.shared.auth.session.user.id else { return }
        // Before the club-tests migration has run, this is simply none.
        clubTests = (try? await ClubTestService.mine()) ?? .none
        let tests = StandardTest.all + clubTests.tests.map(\.asTest)

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
            guard let test = tests.first(where: { $0.key == row.distanceKey }) else { continue }
            guard let existing = bestByKey[row.distanceKey] else {
                bestByKey[row.distanceKey] = row
                continue
            }
            let isBetter = test.isDurationBased ? row.distanceM > existing.distanceM : row.timeMs < existing.timeMs
            if isBetter { bestByKey[row.distanceKey] = row }
        }

        let clubTestsByKey = Dictionary(uniqueKeysWithValues: clubTests.tests.map { ($0.key, $0) })
        tiles = tests.map { test in
            // Duration tests show distance covered (unit-aware); distance
            // tests show total time taken — elapsed time, not a split, so
            // it stays formattedDurationMs regardless of paceDisplay.
            let display = bestByKey[test.key].map { row in
                test.isDurationBased ? row.distanceM.formattedMetres : row.timeMs.formattedDurationMs
            }
            return Tile(test: test, clubTest: clubTestsByKey[test.key], displayValue: display)
        }
        await loadPredictions()
    }

    /// The Pace Engine predicts a distance, so timed tests (4min, 30min, a club's 30s) get none.
    @MainActor
    private func loadPredictions() async {
        let distances = tiles.compactMap { tile -> Double? in
            if case .distance(let metres) = tile.test.target { Double(metres) } else { nil }
        }
        guard let predictions = try? await PredictionService.predictions(for: distances) else { return }
        tiles = tiles.map { tile in
            var tile = tile
            if case .distance(let metres) = tile.test.target,
               let prediction = predictions[Double(metres)],
               PredictionService.isShowable(prediction) {
                tile.predicted = prediction.predictedTotalTimeFormatted
            }
            return tile
        }
    }

    /// Deletes a club test and every result posted to it, then refreshes the grid.
    @MainActor
    func delete(_ clubTest: ClubTest) async throws {
        try await ClubTestService.delete(clubTest.id)
        await loadOwnPBs()
    }
}
