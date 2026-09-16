//
//  ProfileViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns the profile screen's header, streak, season strip and PB board —
/// task 15's first half. Charts (e), (f) and the photo grid (g) are the
/// second half.
@Observable
final class ProfileViewModel {
    struct PBTile: Identifiable {
        let test: StandardTest
        var id: String { test.key }
        let distanceM: Int?
        let timeMs: Int?
        let splitMs: Int?
        let setAt: Date?

        /// Empty tiles have nothing to chart, and the brief's gold PB flag
        /// only applies to a result that exists — both read false when nil.
        var hasResult: Bool { setAt != nil }

        /// Time for a distance test, distance for a duration test —
        /// matches the picker tiles on the Tests tab (task 14).
        var displayValue: String? {
            guard hasResult, let timeMs, let distanceM else { return nil }
            return test.isDurationBased ? "\(distanceM.formattedWithGrouping)m" : timeMs.formattedDurationMs
        }

        var splitDisplay: String? {
            splitMs.map { "\($0.formattedDurationMs) /500m" }
        }

        var dateDisplay: String? {
            guard let setAt else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: setAt)
        }

        /// The brief's 30-day PB gold flag — a different window from the
        /// test leaderboard's own 7-day one (task 14); each screen states
        /// its own.
        var isRecentPB: Bool {
            guard let setAt else { return false }
            return setAt >= Date().addingTimeInterval(-30 * 86400)
        }
    }

    var displayName = ""
    var categoryLabel = ""
    var clubName: String?

    var streakDays = 0
    var restDaysUsedThisWeek = 0
    var restDaysAllowedPerWeek = 2

    var seasonTotalDistanceM = 0
    var seasonSessionCount = 0
    var longestStreakDays = 0

    var pbTiles: [PBTile] = StandardTest.all.map { PBTile(test: $0, distanceM: nil, timeMs: nil, splitMs: nil, setAt: nil) }

    var isLoading = false
    var errorMessage: String?

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userId = try await SupabaseService.shared.auth.session.user.id

            struct ProfileRow: Decodable {
                struct Club: Decodable { let name: String }
                let displayName: String
                let category: RowerCategory
                let club: Club?
                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                    case category
                    case club = "clubs"
                }
            }
            let profile: ProfileRow = try await SupabaseService.shared
                .from("profiles")
                .select("display_name, category, clubs(name)")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            displayName = profile.displayName
            categoryLabel = profile.category.rawValue.uppercased()
            clubName = profile.club?.name

            async let streak = Self.fetchStreak(userId: userId)
            async let dailyTotals = Self.fetchDailyTotals(userId: userId)
            async let testResults = Self.fetchTestResults(userId: userId)

            let (streakResult, totals, results) = try await (streak, dailyTotals, testResults)

            streakDays = streakResult.activeDays
            restDaysUsedThisWeek = streakResult.restUsedThisWeek

            seasonTotalDistanceM = totals.reduce(0) { $0 + $1.distanceM }
            seasonSessionCount = totals.reduce(0) { $0 + $1.sessionCount }
            longestStreakDays = Self.longestStreak(dailyTotals: totals)

            pbTiles = Self.bestPerDistance(results)
            errorMessage = nil
        } catch {
            print("Profile load failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Streak

    private struct StreakResult: Decodable {
        let activeDays: Int
        let restUsedThisWeek: Int
        enum CodingKeys: String, CodingKey {
            case activeDays = "active_days"
            case restUsedThisWeek = "rest_used_this_week"
        }
    }

    private struct StreakParams: Encodable {
        let pUser: UUID
        let pToday: String
        enum CodingKeys: String, CodingKey { case pUser = "p_user"; case pToday = "p_today" }
    }

    private static func fetchStreak(userId: UUID) async throws -> StreakResult {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let params = StreakParams(pUser: userId, pToday: formatter.string(from: Date()))
        let results: [StreakResult] = try await SupabaseService.shared
            .rpc("current_streak", params: params)
            .execute()
            .value
        return results.first ?? StreakResult(activeDays: 0, restUsedThisWeek: 0)
    }

    // MARK: - Season strip + longest streak

    struct DailyTotalRow: Decodable {
        let day: String
        let distanceM: Int
        let sessionCount: Int
        enum CodingKeys: String, CodingKey {
            case day
            case distanceM = "distance_m"
            case sessionCount = "session_count"
        }
    }

    private static func fetchDailyTotals(userId: UUID) async throws -> [DailyTotalRow] {
        try await SupabaseService.shared
            .from("daily_totals")
            .select("day, distance_m, session_count")
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    /// Mirrors `current_streak`'s rest-day rule (2 misses absorbed per ISO
    /// week, a 3rd breaks the run) but walks forward across the user's
    /// whole history to find the longest run ever, rather than backward
    /// from today for only the current one — there's no SQL function for
    /// this, so it's computed here from the same rows the season strip
    /// already needs.
    private static func longestStreak(dailyTotals: [DailyTotalRow]) -> Int {
        let activeDays = Set(dailyTotals.filter { $0.sessionCount > 0 }.map(\.day))
        guard !activeDays.isEmpty else { return 0 }

        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        guard let earliest = activeDays.compactMap(formatter.date(from:)).min() else { return 0 }

        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday, matching current_streak's ISO week

        var current = 0
        var maxRun = 0
        var missesByWeek: [Int: Int] = [:]
        var date = earliest
        let today = calendar.startOfDay(for: Date())

        while date <= today {
            let weekKey = calendar.component(.weekOfYear, from: date) * 10000 + calendar.component(.yearForWeekOfYear, from: date)
            if activeDays.contains(formatter.string(from: date)) {
                current += 1
            } else {
                let misses = missesByWeek[weekKey, default: 0]
                if misses >= 2 {
                    current = 0
                } else {
                    missesByWeek[weekKey] = misses + 1
                }
            }
            maxRun = max(maxRun, current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return maxRun
    }

    // MARK: - PB board

    struct TestResultRow: Decodable {
        let distanceKey: String
        let distanceM: Int
        let timeMs: Int
        let splitMs: Int
        let setAt: Date
        enum CodingKeys: String, CodingKey {
            case distanceKey = "distance_key"
            case distanceM = "distance_m"
            case timeMs = "time_ms"
            case splitMs = "split_ms"
            case setAt = "set_at"
        }
    }

    private static func fetchTestResults(userId: UUID) async throws -> [TestResultRow] {
        try await SupabaseService.shared
            .from("test_results")
            .select("distance_key, distance_m, time_ms, split_ms, set_at")
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    private static func bestPerDistance(_ results: [TestResultRow]) -> [PBTile] {
        var bestByKey: [String: TestResultRow] = [:]
        for row in results {
            guard let test = StandardTest.all.first(where: { $0.key == row.distanceKey }) else { continue }
            guard let existing = bestByKey[row.distanceKey] else {
                bestByKey[row.distanceKey] = row
                continue
            }
            let isBetter = test.isDurationBased ? row.distanceM > existing.distanceM : row.timeMs < existing.timeMs
            if isBetter { bestByKey[row.distanceKey] = row }
        }

        return StandardTest.all.map { test in
            guard let row = bestByKey[test.key] else {
                return PBTile(test: test, distanceM: nil, timeMs: nil, splitMs: nil, setAt: nil)
            }
            return PBTile(test: test, distanceM: row.distanceM, timeMs: row.timeMs, splitMs: row.splitMs, setAt: row.setAt)
        }
    }
}
