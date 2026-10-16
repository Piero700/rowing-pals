//
//  ClubMember.swift
//  Rowing Pals
//

import Foundation

/// A rowing member of the coach's club as the Calendar's lists show them: name, picture and the
/// side they row on (decision 67).
nonisolated struct ClubMember: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let displayName: String
    let side: RowingSide?

    enum CodingKeys: String, CodingKey {
        case id, side
        case displayName = "display_name"
    }

    init(id: UUID, displayName: String, side: RowingSide? = nil) {
        self.id = id
        self.displayName = displayName
        self.side = side
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        // Absent before docs/migrations/2026-10-16-coach-version.sql has run.
        side = try? c.decodeIfPresent(RowingSide.self, forKey: .side)
    }
}
