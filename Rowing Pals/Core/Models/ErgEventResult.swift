//
//  ErgEventResult.swift
//  Rowing Pals
//

import Foundation

/// One rower's best piece counted for an erg event (decision 91; an `erg_event_board` row).
nonisolated struct ErgEventResult: Decodable, Identifiable, Equatable, Sendable {
    let userId: UUID
    let displayName: String
    let gender: RowerGender?
    let category: RowerCategory?
    let distanceM: Int
    let timeMs: Int
    let sessionId: UUID

    var id: UUID { userId }

    /// Pace per 500 m, in milliseconds.
    var splitMs: Int { distanceM > 0 ? Int((Double(timeMs) * 500 / Double(distanceM)).rounded()) : 0 }

    enum CodingKeys: String, CodingKey {
        case gender, category
        case userId = "user_id"
        case displayName = "display_name"
        case distanceM = "distance_m"
        case timeMs = "time_ms"
        case sessionId = "session_id"
    }

    init(userId: UUID, displayName: String, gender: RowerGender?, category: RowerCategory?, distanceM: Int, timeMs: Int, sessionId: UUID) {
        self.userId = userId
        self.displayName = displayName
        self.gender = gender
        self.category = category
        self.distanceM = distanceM
        self.timeMs = timeMs
        self.sessionId = sessionId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(UUID.self, forKey: .userId)
        displayName = try c.decode(String.self, forKey: .displayName)
        gender = try? c.decodeIfPresent(RowerGender.self, forKey: .gender)
        category = try? c.decodeIfPresent(RowerCategory.self, forKey: .category)
        distanceM = try c.decode(Int.self, forKey: .distanceM)
        timeMs = try c.decode(Int.self, forKey: .timeMs)
        sessionId = try c.decode(UUID.self, forKey: .sessionId)
    }
}
