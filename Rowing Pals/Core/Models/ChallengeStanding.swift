//
//  ChallengeStanding.swift
//  Rowing Pals
//

import Foundation

/// One rower in a challenge (decision 91; a `challenge_standings` row): their metres on the
/// leaderboards between its days, and the club's squads they're in.
nonisolated struct ChallengeStanding: Decodable, Identifiable, Equatable, Sendable {
    let userId: UUID
    let displayName: String
    let metres: Int
    let squadIds: [UUID]

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case metres
        case userId = "user_id"
        case displayName = "display_name"
        case squadIds = "squad_ids"
    }

    init(userId: UUID, displayName: String, metres: Int, squadIds: [UUID] = []) {
        self.userId = userId
        self.displayName = displayName
        self.metres = metres
        self.squadIds = squadIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(UUID.self, forKey: .userId)
        displayName = try c.decode(String.self, forKey: .displayName)
        metres = try c.decodeIfPresent(Int.self, forKey: .metres) ?? 0
        squadIds = try c.decodeIfPresent([UUID].self, forKey: .squadIds) ?? []
    }
}
