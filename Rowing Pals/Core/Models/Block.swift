//
//  Block.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `blocks` table in docs/schema.sql. No `id` — the primary
/// key is (blocker_id, blocked_id).
struct Block: Codable {
    var blockerId: UUID
    var blockedId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
        case createdAt = "created_at"
    }
}
