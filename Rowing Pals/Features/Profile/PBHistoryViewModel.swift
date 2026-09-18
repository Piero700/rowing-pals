//
//  PBHistoryViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns one distance's PB progression chart — every historical
/// `test_results` row for that distance, in order, with each point flagged
/// for whether it was a personal best *at the time it was set* (not just
/// the single overall best) — a rower can set several PBs in a row before
/// one that doesn't improve on the last.
@Observable
final class PBHistoryViewModel {
    struct Point: Identifiable {
        let id: UUID
        let date: Date
        /// Milliseconds for a distance test, metres for a duration test —
        /// whichever `StandardTest.isDurationBased` says this test uses.
        let value: Double
        let isPB: Bool
    }

    /// Redesign phase D — PB history screen (see
    /// docs/design/rowing-pals-redesign-handoff-v2.md §2 Screen 10): a
    /// 3-button period control over the same underlying history. PB flags
    /// (`Point.isPB`) are always computed over the *full* history in
    /// `load()`, never re-derived per window — whether a result was a PB is
    /// a historical fact independent of which period is currently viewed.
    enum Period: Int, CaseIterable {
        case threeMonths, sixMonths, all

        var label: String {
            switch self {
            case .threeMonths: "3 months"
            case .sixMonths: "6 months"
            case .all: "All time"
            }
        }

        /// nil = no cutoff.
        var months: Int? {
            switch self {
            case .threeMonths: 3
            case .sixMonths: 6
            case .all: nil
            }
        }
    }

    let test: StandardTest
    var period: Period = .all
    /// Every result ever, PB-flagged — set once by `load()`. `points` below
    /// is the period-filtered view apps actually render.
    private(set) var allPoints: [Point] = []
    var currentBestLabel: String?
    var isLoading = false
    var errorMessage: String?

    /// The period-filtered points the chart and list actually show.
    var points: [Point] {
        guard let months = period.months else { return allPoints }
        guard let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: Date()) else { return allPoints }
        return allPoints.filter { $0.date >= cutoff }
    }

    /// The most recent PB strictly before the current one, for the "+N
    /// faster/further" gain badge — nil when the current PB is the only
    /// result, or the first result ever (nothing to compare against).
    var previousBestValue: Double? {
        let pbs = allPoints.filter(\.isPB)
        guard pbs.count >= 2 else { return nil }
        return pbs[pbs.count - 2].value
    }

    init(test: StandardTest) {
        self.test = test
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userId = try await SupabaseService.shared.auth.session.user.id

            struct Row: Decodable {
                let id: UUID
                let distanceM: Int
                let timeMs: Int
                let setAt: Date
                enum CodingKeys: String, CodingKey {
                    case id
                    case distanceM = "distance_m"
                    case timeMs = "time_ms"
                    case setAt = "set_at"
                }
            }

            let rows: [Row] = try await SupabaseService.shared
                .from("test_results")
                .select("id, distance_m, time_ms, set_at")
                .eq("user_id", value: userId)
                .eq("distance_key", value: test.key)
                .order("set_at")
                .execute()
                .value

            var runningBest: Double?
            allPoints = rows.map { row in
                let value = test.isDurationBased ? Double(row.distanceM) : Double(row.timeMs)
                let isPB: Bool
                if let runningBest {
                    isPB = test.isDurationBased ? value > runningBest : value < runningBest
                } else {
                    isPB = true // the first result ever is trivially a PB
                }
                if isPB { runningBest = value }
                return Point(id: row.id, date: row.setAt, value: value, isPB: isPB)
            }

            let overallBest = test.isDurationBased ? allPoints.map(\.value).max() : allPoints.map(\.value).min()
            currentBestLabel = overallBest.map { Self.format($0, isDurationBased: test.isDurationBased, unit: .current) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Duration tests: distance covered, unit-aware (`unit`, read fresh
    /// from `DistanceUnit.current` by view-model callers; a View passes its
    /// own `@AppStorage`-backed value instead — see `PBProgressionView`'s
    /// chart axis). Distance tests: total time taken to finish — elapsed
    /// time, never a split/watts value, so it always stays formattedDurationMs.
    static func format(_ value: Double, isDurationBased: Bool, unit: DistanceUnit) -> String {
        isDurationBased ? Int(value).formattedDistance(unit: unit) : Int(value).formattedDurationMs
    }
}
