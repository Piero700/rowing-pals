//
//  Report.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `reports` table in docs/schema.sql. Exactly one of
/// `sessionId`/`commentId` is set, per the table's own check constraint.
struct Report: Codable, Identifiable {
    let id: UUID
    var reporterId: UUID
    var sessionId: UUID?
    var commentId: UUID?
    var reason: String
    var status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case sessionId = "session_id"
        case commentId = "comment_id"
        case reason, status
        case createdAt = "created_at"
    }
}
