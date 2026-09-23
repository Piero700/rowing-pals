//
//  ProfileViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns the profile screen's header, streak, season strip, PB board,
/// weekly volume chart, consistency calendar and photo grid — all of
/// task 15.
@Observable
final class ProfileViewModel {
    struct WeeklyVolume: Identifiable {
        let weekStart: Date
        var id: Date { weekStart }
        let distanceM: Int
        let isCurrentWeek: Bool
    }

    struct ConsistencyDay: Identifiable {
        let date: Date
        var id: Date { date }
        let distanceM: Int
        /// 0-25, oldest to current — the grid's horizontal position.
        let column: Int
        /// 0 = Monday ... 6 = Sunday — the grid's vertical position.
        let row: Int

        /// Four steps of the cyan ramp, per the design brief — 0 is the
        /// faint empty square for a day with nothing logged.
        var shadeLevel: Int {
            switch distanceM {
            case 0: 0
            case 1..<3000: 1
            case 3000..<7000: 2
            default: 3
            }
        }
    }

    struct ProfilePhoto: Identifiable {
        let id: UUID // session id
        let distanceM: Int
        let monitorPath: String?
    }
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
        /// matches the picker tiles on the Tests tab (task 14). Reads the
        /// distance-unit preference fresh from `UserDefaults` on every
        /// access (a computed property, not cached) — this is a plain
        /// struct, not a View, so it can't hold `@AppStorage` itself.
        var displayValue: String? {
            guard hasResult, let timeMs, let distanceM else { return nil }
            return test.isDurationBased ? distanceM.formattedMetres : timeMs.formattedDurationMs
        }

        /// Same fresh-read approach for the pace-display preference. The
        /// "/500m" suffix only makes sense for an actual split, so it's
        /// dropped once the preference is watts (`formattedPace` already
        /// appends "W" to the watts value itself).
        var splitDisplay: String? {
            splitMs.map { splitMs in
                let paceDisplay = PaceDisplay.current
                let formatted = splitMs.formattedPace(display: paceDisplay)
                return paceDisplay == .split ? "\(formatted) /500m" : formatted
            }
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

    var weeklyTargetM = 0
    var weeklyVolumes: [WeeklyVolume] = []
    var consistencyDays: [ConsistencyDay] = []

    var photos: [ProfilePhoto] = []
    private var signedPhotoURLs: [String: URL] = [:]

    var isLoading = false
    var errorMessage: String?

    func photoURL(for path: String?) -> URL? {
        guard let path else { return nil }
        return signedPhotoURLs[path]
    }

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
                let weeklyTargetM: Int
                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                    case category
                    case club = "clubs"
                    case weeklyTargetM = "weekly_target_m"
                }
            }
            let profile: ProfileRow = try await SupabaseService.shared
                .from("profiles")
                .select("display_name, category, clubs(name), weekly_target_m")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            displayName = profile.displayName
            categoryLabel = profile.category.rawValue.uppercased()
            clubName = profile.club?.name
            weeklyTargetM = profile.weeklyTargetM

            async let streak = Self.fetchStreak(userId: userId)
            async let dailyTotals = Self.fetchDailyTotals(userId: userId)
            async let testResults = Self.fetchTestResults(userId: userId)
            async let sessions = Self.fetchRecentSessions(userId: userId)

            let (streakResult, totals, results, sessionRows) = try await (streak, dailyTotals, testResults, sessions)

            streakDays = streakResult.activeDays
            restDaysUsedThisWeek = streakResult.restUsedThisWeek

            seasonTotalDistanceM = totals.reduce(0) { $0 + $1.distanceM }
            seasonSessionCount = totals.reduce(0) { $0 + $1.sessionCount }
            longestStreakDays = Self.longestStreak(dailyTotals: totals)

            pbTiles = Self.bestPerDistance(results)

            weeklyVolumes = Self.weeklyVolumes(dailyTotals: totals)
            consistencyDays = Self.consistencyGrid(dailyTotals: totals)

            photos = sessionRows.map { ProfilePhoto(id: $0.id, distanceM: $0.totalDistanceM, monitorPath: $0.primarySegmentPath) }
            await fetchPhotoURLs(for: photos)

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

    // MARK: - Weekly volume bars

    /// Twelve calendar-aligned weeks (ISO week, Monday start, matching
    /// `current_streak`'s own convention), oldest first, summed from the
    /// same `daily_totals` rows the season strip and longest-streak
    /// calculation already fetched.
    private static func weeklyVolumes(dailyTotals: [DailyTotalRow], weeks: Int = 12) -> [WeeklyVolume] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: Date())
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }

        var byWeekStart: [Date: Int] = [:]
        for row in dailyTotals {
            guard
                let date = formatter.date(from: row.day),
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            else { continue }
            byWeekStart[weekStart, default: 0] += row.distanceM
        }

        return (0..<weeks).reversed().compactMap { offset in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) else { return nil }
            return WeeklyVolume(weekStart: weekStart, distanceM: byWeekStart[weekStart] ?? 0, isCurrentWeek: offset == 0)
        }
    }

    // MARK: - Consistency calendar

    /// A 7 (Mon-Sun) x 26-week grid ending on the current week, from the
    /// same rows as above — days after today (a partial current week)
    /// simply aren't included, rather than showing as empty-but-real days.
    private static func consistencyGrid(dailyTotals: [DailyTotalRow], weeks: Int = 26) -> [ConsistencyDay] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: Date())
        guard
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
            let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeekStart)
        else { return [] }

        var byDay: [String: Int] = [:]
        for row in dailyTotals { byDay[row.day] = row.distanceM }

        var days: [ConsistencyDay] = []
        for column in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: column, to: gridStart) else { continue }
            for row in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: row, to: weekStart), date <= today else { continue }
                days.append(ConsistencyDay(date: date, distanceM: byDay[formatter.string(from: date)] ?? 0, column: column, row: row))
            }
        }
        return days
    }

    // MARK: - Photo grid

    struct SessionRow: Decodable {
        struct Segment: Decodable {
            let position: Int
            let monitorPhotoPath: String?
            enum CodingKeys: String, CodingKey {
                case position
                case monitorPhotoPath = "monitor_photo_path"
            }
        }

        let id: UUID
        let totalDistanceM: Int
        let segments: [Segment]

        enum CodingKeys: String, CodingKey {
            case id
            case totalDistanceM = "total_distance_m"
            case segments
        }

        var primarySegmentPath: String? {
            segments.min { $0.position < $1.position }?.monitorPhotoPath
        }
    }

    private static func fetchRecentSessions(userId: UUID) async throws -> [SessionRow] {
        try await SupabaseService.shared
            .from("sessions")
            .select("id, total_distance_m, segments(position, monitor_photo_path)")
            .eq("user_id", value: userId)
            .order("posted_at", ascending: false)
            .limit(30)
            .execute()
            .value
    }

    /// Same batched-signed-URL approach as the feed (task 12) — one request
    /// per bucket rather than one per photo.
    @MainActor
    private func fetchPhotoURLs(for photos: [ProfilePhoto]) async {
        let paths = photos.compactMap(\.monitorPath)
        guard !paths.isEmpty else { return }
        guard let results = try? await SupabaseService.shared.storage.from("monitors").createSignedURLs(paths: paths, expiresIn: 3600) else { return }
        for result in results {
            if case .success(let path, let signedURL) = result {
                signedPhotoURLs[path] = signedURL
            }
        }
    }
}
