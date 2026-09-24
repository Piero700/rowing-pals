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
    var ergDistanceM: Int
    var waterDistanceM: Int
    var sessionCount: Int
    /// What the leaderboards read (redesign phase F): a session left off the
    /// leaderboards, and every manual entry, adds to the personal columns
    /// above but not to these. Optional so a database without the phase F
    /// migration still decodes.
    var rankedDistanceM: Int?
    var rankedErgDistanceM: Int?
    var rankedWaterDistanceM: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case day
        case distanceM = "distance_m"
        case ergDistanceM = "erg_distance_m"
        case waterDistanceM = "water_distance_m"
        case sessionCount = "session_count"
        case rankedDistanceM = "ranked_distance_m"
        case rankedErgDistanceM = "ranked_erg_distance_m"
        case rankedWaterDistanceM = "ranked_water_distance_m"
    }
}
