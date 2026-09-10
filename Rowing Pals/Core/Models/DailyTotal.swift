//
//  DailyTotal.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `daily_totals` table in docs/schema.sql. Pre-aggregated per
/// day; every profile chart and the streak read from here rather than
/// scanning `sessions`. Primary key is (user_id, day), no separate id.
struct DailyTotal: Codable {
    var userId: UUID
    /// The user's local calendar day (Postgres `date`) as "yyyy-MM-dd" —
    /// see the note on `Session.sessionDate` for why not `Date`.
    var day: String
    var distanceM: Int
    var sessionCount: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case day
        case distanceM = "distance_m"
        case sessionCount = "session_count"
    }
}
