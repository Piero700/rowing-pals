//
//  EventResponse.swift
//  Rowing Pals
//

import Foundation

/// A rower's "Can you race?" answer, with a reason only coaches see. Mirrors `event_responses`
/// (`answer` is `yes` or `no`).
nonisolated struct EventResponse: Decodable, Equatable, Hashable {
    let eventId: UUID
    let userId: UUID
    let canCome: Bool
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case answer, reason
        case eventId = "event_id"
        case userId = "user_id"
    }

    init(eventId: UUID, userId: UUID, canCome: Bool, reason: String?) {
        self.eventId = eventId
        self.userId = userId
        self.canCome = canCome
        self.reason = reason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try c.decode(UUID.self, forKey: .eventId)
        userId = try c.decode(UUID.self, forKey: .userId)
        canCome = try c.decode(String.self, forKey: .answer) == "yes"
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
    }
}
