//
//  ClubTerm.swift
//  Rowing Pals
//

import Foundation

/// A term's dates, set by the club's coaches, for attendance totals. Mirrors `club_terms`.
nonisolated struct ClubTerm: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    /// "yyyy-MM-dd" calendar days.
    let startsOn: String
    let endsOn: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case startsOn = "starts_on"
        case endsOn = "ends_on"
    }
}
