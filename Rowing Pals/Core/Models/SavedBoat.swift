//
//  SavedBoat.swift
//  Rowing Pals
//

import Foundation

/// A crew a club puts out again and again (decision 70), and how often it's been added to a
/// session.
nonisolated struct SavedBoat: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let boatType: BoatType
    let rigging: Rigging
    /// Custom rigging's seat sides, bow first (decision 74).
    let sides: String?
    let seats: [BoatSeat]
    let uses: Int

    private struct Count: Decodable { let count: Int }

    enum CodingKeys: String, CodingKey {
        case id, name, rigging, sides
        case boatType = "boat_type"
        case seats = "saved_boat_seats"
        case uses = "session_boats"
    }

    init(id: UUID, name: String, boatType: BoatType, rigging: Rigging, sides: String? = nil, seats: [BoatSeat], uses: Int = 0) {
        self.id = id
        self.name = name
        self.boatType = boatType
        self.rigging = rigging
        self.sides = sides
        self.seats = seats
        self.uses = uses
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        boatType = try c.decode(BoatType.self, forKey: .boatType)
        rigging = try c.decodeIfPresent(Rigging.self, forKey: .rigging) ?? .stroke
        sides = try c.decodeIfPresent(String.self, forKey: .sides)
        seats = try c.decodeIfPresent([BoatSeat].self, forKey: .seats) ?? []
        uses = (try? c.decodeIfPresent([Count].self, forKey: .uses))?.first?.count ?? 0
    }

    var setup: BoatSetup { BoatSetup(type: boatType, rigging: rigging, sides: sides) }
}
