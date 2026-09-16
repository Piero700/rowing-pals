//
//  Comment.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `comments` table in docs/schema.sql.
struct Comment: Codable, Identifiable {
    let id: UUID
    var sessionId: UUID
    var userId: UUID
    var body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case body
        case createdAt = "created_at"
    }
}
