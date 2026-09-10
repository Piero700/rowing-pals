//
//  Club.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `clubs` table in docs/schema.sql.
struct Club: Codable, Identifiable {
    let id: UUID
    var name: String
    var location: String?
    var crestPath: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, location
        case crestPath = "crest_path"
        case createdAt = "created_at"
    }
}
