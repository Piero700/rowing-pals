//
//  WaterSession.swift
//  Rowing Pals
//

import Foundation

/// A coach's session on the river (decision 67): when it starts and ends (decision 79), where to
/// meet, the plan, and the practice or race whose answers say who can go. Its boats are
/// `SessionBoat`s.
nonisolated struct WaterSession: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let clubId: UUID
    let practiceId: UUID?
    let eventId: UUID?
    let title: String
    let startsAt: Date
    /// When it finishes: the Feed shows its boats until then (decision 79).
    let endsAt: Date
    let meetAt: String?
    let plan: String?
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, plan
        case clubId = "club_id"
        case practiceId = "practice_id"
        case eventId = "event_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case meetAt = "meet_at"
        case createdBy = "created_by"
    }

    init(id: UUID, clubId: UUID, practiceId: UUID?, eventId: UUID?, title: String, startsAt: Date,
         endsAt: Date? = nil, meetAt: String?, plan: String?, createdBy: UUID?) {
        self.id = id
        self.clubId = clubId
        self.practiceId = practiceId
        self.eventId = eventId
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt ?? startsAt.addingTimeInterval(Self.defaultLength)
        self.meetAt = meetAt
        self.plan = plan
        self.createdBy = createdBy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clubId = try c.decode(UUID.self, forKey: .clubId)
        practiceId = try c.decodeIfPresent(UUID.self, forKey: .practiceId)
        eventId = try c.decodeIfPresent(UUID.self, forKey: .eventId)
        title = try c.decode(String.self, forKey: .title)
        startsAt = try c.decode(Date.self, forKey: .startsAt)
        // Before the end-time migration a session has none: two hours, as a new one defaults to.
        endsAt = try c.decodeIfPresent(Date.self, forKey: .endsAt) ?? startsAt.addingTimeInterval(Self.defaultLength)
        meetAt = try c.decodeIfPresent(String.self, forKey: .meetAt)
        plan = try c.decodeIfPresent(String.self, forKey: .plan)
        createdBy = try c.decodeIfPresent(UUID.self, forKey: .createdBy)
    }

    /// Two hours, as a practice's end defaults to (decision 73).
    static let defaultLength: TimeInterval = 2 * 60 * 60
}
