//
//  ClubVerificationRequest.swift
//  Rowing Pals
//

import Foundation

/// One club's verification, as an app admin sees it (decision 108): an application waiting, one
/// decided, or a club already verified. Mirrors `admin_club_verifications()`.
nonisolated struct ClubVerificationRequest: Decodable, Identifiable, Hashable, Sendable {
    enum Status: String, Decodable, Sendable {
        case pending, approved, declined, none
    }

    let clubId: UUID
    let clubName: String
    let location: String?
    let memberCount: Int
    let requestedByName: String?
    let requestedByUsername: String?
    let message: String?
    let status: Status
    let isVerified: Bool
    let createdAt: Date
    let decidedAt: Date?

    var id: UUID { clubId }

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case clubName = "club_name"
        case location
        case memberCount = "member_count"
        case requestedByName = "requested_by_name"
        case requestedByUsername = "requested_by_username"
        case message, status
        case isVerified = "is_verified"
        case createdAt = "created_at"
        case decidedAt = "decided_at"
    }
}
