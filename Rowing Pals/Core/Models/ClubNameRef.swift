//
//  ClubNameRef.swift
//  Rowing Pals
//

import Foundation

/// A club as it's embedded beside a person (`clubs(*)` on a profile): just what's shown next to
/// them — the name and whether it carries the verified tag (decision 98). `is_verified` decodes
/// leniently, so it reads before docs/migrations/2026-11-05-clubs-open-and-verified.sql has run.
nonisolated struct ClubNameRef: Decodable, Equatable {
    let name: String
    let isVerified: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case isVerified = "is_verified"
    }

    init(name: String, isVerified: Bool = false) {
        self.name = name
        self.isVerified = isVerified
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        isVerified = try c.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
    }
}
