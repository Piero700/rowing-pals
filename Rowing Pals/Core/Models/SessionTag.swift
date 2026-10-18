//
//  SessionTag.swift
//  Rowing Pals
//

import Foundation

/// Someone the poster trained with, tagged on a post (decision 90): a `session_tags` row with the
/// tagged rower's name (`session_id, user_id, profiles(display_name)`).
nonisolated struct SessionTag: Decodable, Identifiable, Equatable, Hashable {
    let sessionId: UUID
    let userId: UUID
    let displayName: String

    var id: UUID { userId }

    private struct Person: Decodable {
        let displayName: String
        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case profile = "profiles"
    }

    init(sessionId: UUID, userId: UUID, displayName: String) {
        self.sessionId = sessionId
        self.userId = userId
        self.displayName = displayName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decode(UUID.self, forKey: .sessionId)
        userId = try c.decode(UUID.self, forKey: .userId)
        displayName = (try? c.decodeIfPresent(Person.self, forKey: .profile))?.displayName ?? "A rower"
    }

    /// "Sam" from "Sam Cole".
    static func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
