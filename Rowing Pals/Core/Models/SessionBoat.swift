//
//  SessionBoat.swift
//  Rowing Pals
//

import Foundation

/// One boat in a water session (decision 67): its name, type, rigging and crew, whether it has
/// been sent, and the saved boat it came from or is kept in.
nonisolated struct SessionBoat: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let sessionId: UUID
    let position: Int
    let name: String
    let boatType: BoatType
    let rigging: Rigging
    let savedBoatId: UUID?
    let sentAt: Date?
    let seats: [BoatSeat]

    enum CodingKeys: String, CodingKey {
        case id, position, name, rigging
        case sessionId = "session_id"
        case boatType = "boat_type"
        case savedBoatId = "saved_boat_id"
        case sentAt = "sent_at"
        case seats = "session_boat_seats"
    }

    init(id: UUID, sessionId: UUID, position: Int = 0, name: String, boatType: BoatType, rigging: Rigging,
         savedBoatId: UUID? = nil, sentAt: Date? = nil, seats: [BoatSeat]) {
        self.id = id
        self.sessionId = sessionId
        self.position = position
        self.name = name
        self.boatType = boatType
        self.rigging = rigging
        self.savedBoatId = savedBoatId
        self.sentAt = sentAt
        self.seats = seats
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sessionId = try c.decode(UUID.self, forKey: .sessionId)
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        name = try c.decode(String.self, forKey: .name)
        boatType = try c.decode(BoatType.self, forKey: .boatType)
        rigging = try c.decodeIfPresent(Rigging.self, forKey: .rigging) ?? .stroke
        savedBoatId = try c.decodeIfPresent(UUID.self, forKey: .savedBoatId)
        sentAt = try c.decodeIfPresent(Date.self, forKey: .sentAt)
        seats = try c.decodeIfPresent([BoatSeat].self, forKey: .seats) ?? []
    }

    var isSent: Bool { sentAt != nil }
}
