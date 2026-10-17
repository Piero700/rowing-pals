//
//  Announcement.swift
//  Rowing Pals
//

import Foundation

/// A coach's notice to every rower in the club (decision 75): a heading on their Feed, a message
/// under it, and when it comes off the Feed.
nonisolated struct Announcement: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let clubId: UUID
    let heading: String
    let message: String?
    let expiresAt: Date
    let createdBy: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, heading, message
        case clubId = "club_id"
        case expiresAt = "expires_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}
