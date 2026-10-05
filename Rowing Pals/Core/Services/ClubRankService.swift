//
//  ClubRankService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Where a rower stands among their own club (docs/design/v2-decisions.md #20): this week's
/// volume, and their best 2k and 5k. Same rules as the Rankings screen's defaults — ranked
/// metres only, weeks start on Monday, every gender and level, best result per rower — so a
/// number here matches the club board. Clubmates the viewer isn't allowed to see (private,
/// not followed) aren't returned by the database, exactly as on the Rankings screen.
enum ClubRankService {
    struct Ranks: Equatable {
        var weeklyVolume: Int?
        var twoK: Int?
        var fiveK: Int?
    }

    static func ranks(for userId: UUID, clubId: UUID, today: Date = Date()) async throws -> Ranks {
        struct Member: Decodable { let id: UUID }
        let members: [Member] = try await SupabaseService.shared
            .from("profiles")
            .select("id")
            .eq("club_id", value: clubId)
            // Coach-only accounts are never ranked (decision 39).
            .eq("is_rower", value: true)
            .execute()
            .value
        let ids = members.map(\.id)
        guard ids.contains(userId) else { return Ranks() }

        struct VolumeRow: Decodable {
            let userId: UUID
            let rankedDistanceM: Int
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case rankedDistanceM = "ranked_distance_m"
            }
        }
        struct ResultRow: Decodable {
            let userId: UUID
            let distanceKey: String
            let distanceM: Int
            let timeMs: Int
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case distanceKey = "distance_key"
                case distanceM = "distance_m"
                case timeMs = "time_ms"
            }
        }

        async let volumeRows: [VolumeRow] = SupabaseService.shared
            .from("daily_totals")
            .select("user_id, ranked_distance_m")
            .in("user_id", values: ids)
            .gte("day", value: weekStartString(for: today))
            .execute()
            .value
        async let resultRows: [ResultRow] = SupabaseService.shared
            .from("test_results")
            .select("user_id, distance_key, distance_m, time_ms")
            .in("user_id", values: ids)
            .in("distance_key", values: ["2k", "5k"])
            .execute()
            .value
        let (volumes, results) = try await (volumeRows, resultRows)

        var metres: [UUID: Int] = [:]
        for row in volumes { metres[row.userId, default: 0] += row.rankedDistanceM }

        func bestTimes(_ key: String) -> [UUID: Int] {
            var best: [UUID: Int] = [:]
            for row in results where row.distanceKey == key {
                best[row.userId] = min(best[row.userId] ?? .max, row.timeMs)
            }
            return best
        }

        return Ranks(
            weeklyVolume: rank(of: userId, in: metres.filter { $0.value > 0 }, higherIsBetter: true),
            twoK: rank(of: userId, in: bestTimes("2k"), higherIsBetter: false),
            fiveK: rank(of: userId, in: bestTimes("5k"), higherIsBetter: false)
        )
    }

    /// 1 + the number of rowers strictly better, so equal results share a place. Nil when the
    /// rower has no value to rank.
    nonisolated static func rank(of userId: UUID, in values: [UUID: Int], higherIsBetter: Bool) -> Int? {
        guard let own = values[userId] else { return nil }
        let better = values.values.filter { higherIsBetter ? $0 > own : $0 < own }.count
        return better + 1
    }

    /// Monday of the current week, as the leaderboards' "Week" period uses.
    nonisolated static func weekStartString(for today: Date) -> String {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: start)
    }
}
