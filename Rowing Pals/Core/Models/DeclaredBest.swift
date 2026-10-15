//
//  DeclaredBest.swift
//  Rowing Pals
//

import Foundation

/// A best the rower typed in (decision 64): a distance and the time they'd do it in, from
/// "2k in 6:40" or "20 minutes, 5,400m". Mirrors `declared_bests`. Gives the Pace Engine a
/// starting point; never a test result, a PB or a leaderboard row.
nonisolated struct DeclaredBest: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var distanceM: Int
    var timeMs: Int
    /// "yyyy-MM-dd": the day it was entered, which the engine treats as the day it was rowed.
    var setOn: String
    var userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case distanceM = "distance_m"
        case timeMs = "time_ms"
        case setOn = "set_on"
        case userId = "user_id"
    }

    var splitMs: Int {
        distanceM > 0 ? Int((Double(timeMs) / (Double(distanceM) / 500)).rounded()) : 0
    }
}
