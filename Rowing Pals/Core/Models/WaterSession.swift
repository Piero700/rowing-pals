//
//  WaterSession.swift
//  Rowing Pals
//

import Foundation

/// A coach's session on the river (decision 67): when, where to meet, the plan, and the
/// practice or race whose answers say who can go. Its boats are `SessionBoat`s.
nonisolated struct WaterSession: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let clubId: UUID
    let practiceId: UUID?
    let eventId: UUID?
    let title: String
    let startsAt: Date
    let meetAt: String?
    let plan: String?
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, plan
        case clubId = "club_id"
        case practiceId = "practice_id"
        case eventId = "event_id"
        case startsAt = "starts_at"
        case meetAt = "meet_at"
        case createdBy = "created_by"
    }
}
