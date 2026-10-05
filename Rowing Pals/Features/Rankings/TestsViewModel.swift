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
    /// "Best in your group" (decision 37): 2k and 5k among the viewer's gender and level in
    /// their club. Empty without a club or a gender on file.
    var groupBests: [GroupBest] = []
    /// "Senior men · My club".
    var groupCaption: String?
    var isLoading = false

    /// The tests the group cards show, in order.
    static let groupBestKeys = ["2k", "5k"]

    @MainActor
    func loadOwnPBs() async {
        isLoading = true
        let perf = PerfLog.start()
        defer { isLoading = false; PerfLog.done("Test results", since: perf) }

        guard let userId = try? await SupabaseService.shared.auth.session.user.id else { return }
        // The group cards load alongside everything else; they don't wait for the grid.
        async let groups: Void = loadGroupBests(viewerId: userId)

        nonisolated struct ResultRow: Decodable {
            let distanceKey: String
            let distanceM: Int
            let timeMs: Int

            enum CodingKeys: String, CodingKey {
                case distanceKey = "distance_key"
                case distanceM = "distance_m"
                case timeMs = "time_ms"
            }
        }

        // The club's tests and your results, at once. Before the club-tests migration has run,
        // the club's tests are simply none.
        async let clubTestsRequest = try? await ClubTestService.mine()
        async let resultsRequest: [ResultRow]? = try? await SupabaseService.shared
            .from("test_results")
            .select("distance_key, distance_m, time_ms")
            .eq("user_id", value: userId)
            .execute()
            .value
        let (myClubTests, resultRows) = await (clubTestsRequest, resultsRequest)
        clubTests = myClubTests ?? .none
        let tests = StandardTest.all + clubTests.tests.map(\.asTest)
        guard let rows = resultRows else {
            await groups
            return
        }

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
        await groups
    }

    @MainActor
    private func loadGroupBests(viewerId: UUID) async {
        guard let group = await ViewerGroup.load(), let gender = group.gender, group.clubName != nil,
              let memberIds = try? await SocialScope.myClub.userIds(), !memberIds.isEmpty else {
            groupBests = []
            groupCaption = nil
            return
        }
        // Known at once (the viewer context is cached), so the section takes its place before
        // its numbers arrive and the grid below doesn't jump.
        groupCaption = group.filters.captionText
        nonisolated struct Row: Decodable {
            struct Author: Decodable {
                let displayName: String
                enum CodingKeys: String, CodingKey { case displayName = "display_name" }
            }
            let userId: UUID
            let distanceKey: String
            let timeMs: Int
            let author: Author
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case distanceKey = "distance_key"
                case timeMs = "time_ms"
                case author = "profiles"
            }
        }
        guard let rows: [Row] = try? await SupabaseService.shared
            .from("test_results")
            .select("user_id, distance_key, time_ms, profiles(display_name)")
            .in("user_id", values: memberIds)
            .in("distance_key", values: Self.groupBestKeys)
            .eq("gender_at_time", value: gender.rawValue)
            .eq("category_at_time", value: group.level.rawValue)
            .execute()
            .value
        else {
            // No numbers to show: hide the section rather than leave placeholders.
            groupCaption = nil
            return
        }

        groupBests = Self.groupBestKeys.compactMap { key in
            guard let test = StandardTest.all.first(where: { $0.key == key }) else { return nil }
            let results = rows.filter { $0.distanceKey == key }
                .map { GroupBest.Result(userId: $0.userId, name: $0.author.displayName, timeMs: $0.timeMs) }
            return GroupBest.make(test: test, results: results, viewerId: viewerId)
        }
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
