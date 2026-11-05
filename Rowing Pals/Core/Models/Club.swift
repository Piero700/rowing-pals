//
//  Club.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `clubs` table in docs/schema.sql. The fields from
/// docs/migrations/2026-09-30-clubs.sql decode leniently, so a build running before that
/// migration still reads clubs.
struct Club: Codable, Identifiable {
    let id: UUID
    var name: String
    var location: String?
    var crestPath: String?
    var description: String?
    var joinPolicy: ClubJoinPolicy
    var focus: ClubFocus
    /// Approved by the app's team (decision 98): shows the verified tag beside the name. False
    /// before docs/migrations/2026-11-05-clubs-open-and-verified.sql.
    var isVerified: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, location, description, focus
        case crestPath = "crest_path"
        case joinPolicy = "join_policy"
        case createdAt = "created_at"
        case isVerified = "is_verified"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        crestPath = try c.decodeIfPresent(String.self, forKey: .crestPath)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        joinPolicy = try c.decodeIfPresent(ClubJoinPolicy.self, forKey: .joinPolicy) ?? .open
        // A focus this app no longer offers ("On-water rowing", before the erg-only migration
        // has run) reads as All rowing rather than failing the whole club.
        focus = (try c.decodeIfPresent(String.self, forKey: .focus)).flatMap(ClubFocus.init(rawValue:)) ?? .allRowing
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isVerified = try c.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
    }
}
