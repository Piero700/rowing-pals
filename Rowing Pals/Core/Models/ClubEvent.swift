//
//  ClubEvent.swift
//  Rowing Pals
//

import Foundation

/// A race, regatta or other event on the club's calendar (decision 68), and whether the coach is
/// asking who can come. Mirrors `club_events` with its `event_squads`.
nonisolated struct ClubEvent: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let clubId: UUID
    let kind: EventKind
    let name: String
    /// "yyyy-MM-dd" calendar days; the same for a one-day event.
    let firstDay: String
    let lastDay: String
    let place: String?
    let note: String?
    let asksAvailability: Bool
    /// The squads it's for; empty for the whole club.
    let squadIds: [UUID]

    private struct SquadRow: Decodable {
        let squadId: UUID
        enum CodingKeys: String, CodingKey { case squadId = "squad_id" }
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, name, place, note
        case clubId = "club_id"
        case firstDay = "first_day"
        case lastDay = "last_day"
        case asksAvailability = "asks_availability"
        case squads = "event_squads"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clubId = try c.decode(UUID.self, forKey: .clubId)
        kind = try c.decode(EventKind.self, forKey: .kind)
        name = try c.decode(String.self, forKey: .name)
        firstDay = try c.decode(String.self, forKey: .firstDay)
        lastDay = try c.decode(String.self, forKey: .lastDay)
        place = try c.decodeIfPresent(String.self, forKey: .place)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        asksAvailability = try c.decodeIfPresent(Bool.self, forKey: .asksAvailability) ?? true
        squadIds = (try c.decodeIfPresent([SquadRow].self, forKey: .squads) ?? []).map(\.squadId)
    }

    init(id: UUID, clubId: UUID, kind: EventKind, name: String, firstDay: String, lastDay: String,
         place: String? = nil, note: String? = nil, asksAvailability: Bool = true, squadIds: [UUID] = []) {
        self.id = id
        self.clubId = clubId
        self.kind = kind
        self.name = name
        self.firstDay = firstDay
        self.lastDay = lastDay
        self.place = place
        self.note = note
        self.asksAvailability = asksAvailability
        self.squadIds = squadIds
    }
}
