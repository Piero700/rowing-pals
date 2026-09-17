//
//  TestLeaderboardViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns one standard distance's leaderboard — Male/Female on top, All/
/// Novice/Senior beneath, filtered on `test_results`' own snapshot columns
/// (`gender_at_time`/`category_at_time`), never a live join to `profiles`.
/// Only each rower's best result for this distance is shown.
@Observable
final class TestLeaderboardViewModel {
    enum CategoryFilter: Int, CaseIterable {
        case all, novice, senior

        var label: String {
            switch self {
            case .all: "All"
            case .novice: "Novice"
            case .senior: "Senior"
            }
        }

        var rowerCategory: RowerCategory? {
            switch self {
            case .all: nil
            case .novice: .novice
            case .senior: .senior
            }
        }
    }

    struct Row: Identifiable {
        let id: UUID // user_id — one row per rower, already reduced to their best
        let rank: Int
        let name: String
        let club: String?
        /// Time for a distance test, distance for a duration test — see
        /// `StandardTest.isDurationBased`.
        let primaryValue: String
        let splitValue: String
        let category: RowerCategory
        let dateLabel: String
        let isRecentPB: Bool
        /// From a batched `daily_totals` fetch computed client-side via
        /// `StreakCalculator`, not a `current_streak(...)` RPC call per row.
        let streakDays: Int
    }

    let test: StandardTest
    var gender: RowerGender = .male {
        didSet { guard oldValue != gender else { return }; Task { await reload() } }
    }
    var category: CategoryFilter = .all {
        didSet { guard oldValue != category else { return }; Task { await reload() } }
    }

    var rows: [Row] = []
    var isLoading = false
    var errorMessage: String?

    private var reloadTask: Task<Void, Never>?
    private var hasLoadedOnce = false

    init(test: StandardTest) {
        self.test = test
    }

    @MainActor
    func loadInitial() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true

        // Best-effort default to the viewer's own gender, same as the
        // metres leaderboard — so they land on the board that contains them.
        if let userId = try? await SupabaseService.shared.auth.session.user.id {
            let profile: Profile? = try? await SupabaseService.shared
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            if let ownGender = profile?.gender, ownGender != gender {
                gender = ownGender // triggers reload() via didSet
                return
            }
        }
        await reload()
    }

    /// Cancels any reload already in flight before starting a new one —
    /// same fix as the metres leaderboard's: without it, rapid filter taps
    /// let whichever response resolves last win, regardless of which
    /// filters are actually selected by the time it lands.
    @MainActor
    func reload() async {
        reloadTask?.cancel()
        let task = Task { await performReload() }
        reloadTask = task
        await task.value
    }

    @MainActor
    private func performReload() async {
        guard !Task.isCancelled else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            struct ResultRow: Decodable {
                struct Author: Decodable {
                    struct Club: Decodable { let name: String }
                    let displayName: String
                    let club: Club?
                    enum CodingKeys: String, CodingKey {
                        case displayName = "display_name"
                        case club = "clubs"
                    }
                }

                let userId: UUID
                let distanceM: Int
                let timeMs: Int
                let splitMs: Int
                let categoryAtTime: RowerCategory
                let setAt: Date
                let author: Author

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case distanceM = "distance_m"
                    case timeMs = "time_ms"
                    case splitMs = "split_ms"
                    case categoryAtTime = "category_at_time"
                    case setAt = "set_at"
                    case author = "profiles"
                }
            }

            var query = SupabaseService.shared
                .from("test_results")
                .select("""
                user_id, distance_m, time_ms, split_ms, category_at_time, set_at, \
                profiles(display_name, clubs(name))
                """)
                .eq("distance_key", value: test.key)
                .eq("gender_at_time", value: gender.rawValue)
            if let categoryValue = category.rowerCategory {
                query = query.eq("category_at_time", value: categoryValue.rawValue)
            }

            let resultRows: [ResultRow] = try await query.execute().value
            guard !Task.isCancelled else { return }

            // One row per rower — their best result for this distance,
            // "better" meaning faster (distance tests) or farther
            // (duration tests).
            var bestByUser: [UUID: ResultRow] = [:]
            for row in resultRows {
                guard let existing = bestByUser[row.userId] else {
                    bestByUser[row.userId] = row
                    continue
                }
                let isBetter = test.isDurationBased ? row.distanceM > existing.distanceM : row.timeMs < existing.timeMs
                if isBetter { bestByUser[row.userId] = row }
            }

            let sorted = bestByUser.values.sorted {
                test.isDurationBased ? $0.distanceM > $1.distanceM : $0.timeMs < $1.timeMs
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400)

            // Streak, batched into one `daily_totals` query across every
            // rower on this board rather than one `current_streak(...)`
            // RPC call per row — see StreakCalculator's doc comment and
            // docs/schema.sql's `current_streak`. Best-effort: a failure
            // here just leaves streak badges unresolved, not the whole board.
            struct StreakRow: Decodable {
                let userId: UUID
                let day: String
                let sessionCount: Int
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case day
                    case sessionCount = "session_count"
                }
            }
            var activeDaysByUser: [UUID: Set<String>] = [:]
            if !sorted.isEmpty {
                let streakRows: [StreakRow] = (try? await SupabaseService.shared
                    .from("daily_totals")
                    .select("user_id, day, session_count")
                    .in("user_id", values: sorted.map(\.userId))
                    .execute()
                    .value) ?? []
                for row in streakRows where row.sessionCount > 0 {
                    activeDaysByUser[row.userId, default: []].insert(row.day)
                }
            }

            rows = sorted.enumerated().map { index, row in
                Row(
                    id: row.userId,
                    rank: index + 1,
                    name: row.author.displayName,
                    club: row.author.club?.name,
                    // Duration tests (e.g. 30'): the metric is distance covered, unit-aware.
                    // Distance tests (e.g. 2k): the metric is total time taken to finish —
                    // elapsed time, never watts, so this stays formattedDurationMs.
                    primaryValue: test.isDurationBased ? row.distanceM.formattedDistance(unit: .current) : row.timeMs.formattedDurationMs,
                    splitValue: row.splitMs.formattedPace(display: .current),
                    category: row.categoryAtTime,
                    dateLabel: formatter.string(from: row.setAt),
                    isRecentPB: row.setAt >= sevenDaysAgo,
                    streakDays: StreakCalculator.streak(activeDays: activeDaysByUser[row.userId] ?? [])
                )
            }
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            print("Test leaderboard query failed (\(test.key), gender \(gender), category \(category)): \(error)")
            errorMessage = error.localizedDescription
        }
    }
}
