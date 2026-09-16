//
//  MetresLeaderboardViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns the metres leaderboard's Week/Month/Year period, Male/Female
/// filter, All/Erg/Water source, and Following/My Club/Global scope.
/// Aggregates from `daily_totals` only, never `sessions`, per task 13.
@Observable
final class MetresLeaderboardViewModel {
    enum Period: Int, CaseIterable {
        case week, month, year

        var label: String {
            switch self {
            case .week: "Week"
            case .month: "Month"
            case .year: "Year"
            }
        }
    }

    enum Source: Int, CaseIterable {
        case all, erg, water

        var label: String {
            switch self {
            case .all: "All"
            case .erg: "Erg"
            case .water: "Water"
            }
        }
    }

    struct Row: Identifiable {
        let userId: UUID
        var id: UUID { userId }
        let rank: Int
        let name: String
        let club: String?
        let metres: Int
        /// Fraction of `metres` that's erg, for the two-tone bar — always
        /// the row's true erg/water mix, regardless of which figure
        /// `source` currently ranks by.
        let ergFraction: Double
        let isCurrentUser: Bool
    }

    var period: Period = .week {
        didSet { guard oldValue != period else { return }; Task { await reload() } }
    }
    /// Defaults to Male until the viewer's own profile loads and corrects
    /// it — see `loadInitial()` — so a female rower doesn't land on a board
    /// that never contains her.
    var gender: RowerGender = .male {
        didSet { guard oldValue != gender else { return }; Task { await reload() } }
    }
    var scope: SocialScope = .global {
        didSet { guard oldValue != scope else { return }; Task { await reload() } }
    }
    /// Re-sorting by a different source never needs a new query — every
    /// aggregate this view model holds already has all three figures.
    var source: Source = .all {
        didSet { guard oldValue != source else { return }; rankedRows = Self.rank(aggregates, source: source, currentUserId: ownUserId) }
    }

    var rankedRows: [Row] = []
    var isLoading = false
    var errorMessage: String?

    private struct Aggregate {
        let name: String
        let club: String?
        var distanceM = 0
        var ergDistanceM = 0
        var waterDistanceM = 0
    }

    private var aggregates: [UUID: Aggregate] = [:]
    private var ownUserId: UUID?
    private var hasLoadedOnce = false
    /// The in-flight reload, if any — tapping Week/Month/Year (or any other
    /// filter) in quick succession fires a `reload()` per tap, and without
    /// this, whichever request happened to resolve *last* would win and
    /// overwrite the screen, regardless of which tab was actually selected
    /// by the time it landed. Cancelling the previous one on every new call
    /// makes only the most recent request able to commit its results.
    private var reloadTask: Task<Void, Never>?

    @MainActor
    func loadInitial() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true

        // Best-effort: point the gender filter at the viewer's own before
        // the first real query, so they see themselves by default.
        if let userId = try? await SupabaseService.shared.auth.session.user.id {
            ownUserId = userId
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

    /// Cancels any reload already in flight, then runs a fresh one and
    /// waits for it — callers (including `.refreshable`) can `await` this
    /// and know it reflects the current filters, not a superseded one.
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
            let scopeIds = try await scope.userIds()
            guard !Task.isCancelled else { return }
            if let scopeIds, scopeIds.isEmpty {
                aggregates = [:]
                rankedRows = []
                errorMessage = nil
                return
            }

            struct ProfileRow: Decodable {
                struct Club: Decodable { let name: String }
                let id: UUID
                let displayName: String
                let club: Club?

                enum CodingKeys: String, CodingKey {
                    case id
                    case displayName = "display_name"
                    case club = "clubs"
                }
            }

            var profileQuery = SupabaseService.shared
                .from("profiles")
                .select("id, display_name, clubs(name)")
                .eq("gender", value: gender.rawValue)
            if let scopeIds {
                profileQuery = profileQuery.in("id", values: scopeIds)
            }
            let profileRows: [ProfileRow] = try await profileQuery.execute().value
            guard !Task.isCancelled else { return }

            guard !profileRows.isEmpty else {
                aggregates = [:]
                rankedRows = []
                errorMessage = nil
                return
            }

            struct TotalRow: Decodable {
                let userId: UUID
                let distanceM: Int
                let ergDistanceM: Int
                let waterDistanceM: Int

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case distanceM = "distance_m"
                    case ergDistanceM = "erg_distance_m"
                    case waterDistanceM = "water_distance_m"
                }
            }

            let totalRows: [TotalRow] = try await SupabaseService.shared
                .from("daily_totals")
                .select("user_id, distance_m, erg_distance_m, water_distance_m")
                .in("user_id", values: profileRows.map(\.id))
                .gte("day", value: Self.periodStartString(for: period))
                .execute()
                .value
            guard !Task.isCancelled else { return }

            var newAggregates: [UUID: Aggregate] = [:]
            for row in profileRows {
                newAggregates[row.id] = Aggregate(name: row.displayName, club: row.club?.name)
            }
            for row in totalRows {
                newAggregates[row.userId]?.distanceM += row.distanceM
                newAggregates[row.userId]?.ergDistanceM += row.ergDistanceM
                newAggregates[row.userId]?.waterDistanceM += row.waterDistanceM
            }

            aggregates = newAggregates
            rankedRows = Self.rank(newAggregates, source: source, currentUserId: ownUserId)
            errorMessage = nil
        } catch {
            print("Metres leaderboard query failed (period \(period), gender \(gender), scope \(scope)): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// Rows with nothing logged this period are left off entirely, current
    /// user included — a "You · 0m" pinned row has nothing to say.
    private static func rank(_ aggregates: [UUID: Aggregate], source: Source, currentUserId: UUID?) -> [Row] {
        func metres(_ aggregate: Aggregate) -> Int {
            switch source {
            case .all: aggregate.distanceM
            case .erg: aggregate.ergDistanceM
            case .water: aggregate.waterDistanceM
            }
        }

        return aggregates
            .filter { metres($0.value) > 0 }
            .sorted { metres($0.value) > metres($1.value) }
            .enumerated()
            .map { index, entry in
                let (userId, aggregate) = entry
                let fraction = aggregate.distanceM > 0 ? Double(aggregate.ergDistanceM) / Double(aggregate.distanceM) : 0
                return Row(
                    userId: userId,
                    rank: index + 1,
                    name: aggregate.name,
                    club: aggregate.club,
                    metres: metres(aggregate),
                    ergFraction: fraction,
                    isCurrentUser: userId == currentUserId
                )
            }
    }

    /// The period's start day as "yyyy-MM-dd", calendar-aligned — Week is
    /// the current ISO week (Monday start, matching `current_streak`'s own
    /// week convention in docs/schema.sql), Month and Year the current
    /// calendar month/year, not a rolling N-day window. A leaderboard needs
    /// everyone comparing the same window, not each rower's personal
    /// trailing period.
    private static func periodStartString(for period: Period, today: Date = Date()) -> String {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let start: Date
        switch period {
        case .week: start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        case .month: start = calendar.dateInterval(of: .month, for: today)?.start ?? today
        case .year: start = calendar.dateInterval(of: .year, for: today)?.start ?? today
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: start)
    }
}
