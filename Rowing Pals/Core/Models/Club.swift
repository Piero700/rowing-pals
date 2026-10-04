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
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, location, description, focus
        case crestPath = "crest_path"
        case joinPolicy = "join_policy"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        crestPath = try c.decodeIfPresent(String.self, forKey: .crestPath)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        joinPolicy = try c.decodeIfPresent(ClubJoinPolicy.self, forKey: .joinPolicy) ?? .open
        focus = try c.decodeIfPresent(ClubFocus.self, forKey: .focus) ?? .allRowing
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}
