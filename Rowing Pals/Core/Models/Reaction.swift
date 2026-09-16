//
//  Reaction.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `reactions` table in docs/schema.sql. No `id` — the primary
/// key is (session_id, user_id, kind), so one rower can react to a post
/// with several different kinds but never the same kind twice.
struct Reaction: Codable {
    var sessionId: UUID
    var userId: UUID
    /// 'fire', 'grimace', 'clap', 'eyes' — free text, not a DB enum.
    var kind: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case kind
        case createdAt = "created_at"
    }
}
