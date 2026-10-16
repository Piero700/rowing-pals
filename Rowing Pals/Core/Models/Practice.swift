//
//  Practice.swift
//  Rowing Pals
//

import Foundation

/// A practice a coach has set (decisions 39, 68): when, what ("Water", "Erg"…), where, and who
/// it's for. Practices made together as a weekly series share `seriesId`. Mirrors `practices`
/// with its `practice_squads`.
nonisolated struct Practice: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let clubId: UUID
    let seriesId: UUID?
    let startsAt: Date
    let endsAt: Date
    let title: String?
    let place: String?
    /// The two-hour reminder (Settings → Practice reminders).
    let remind: Bool
    let cancelled: Bool
    /// The coach who set it.
    let createdBy: UUID?
    /// The squads it's for; empty for the whole club.
    let squadIds: [UUID]

    private struct SquadRow: Decodable {
        let squadId: UUID
        enum CodingKeys: String, CodingKey { case squadId = "squad_id" }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, place, remind, cancelled
        case clubId = "club_id"
        case seriesId = "series_id"
        case createdBy = "created_by"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case squads = "practice_squads"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clubId = try c.decode(UUID.self, forKey: .clubId)
        seriesId = try c.decodeIfPresent(UUID.self, forKey: .seriesId)
        startsAt = try c.decode(Date.self, forKey: .startsAt)
        endsAt = try c.decode(Date.self, forKey: .endsAt)
        // Absent before docs/migrations/2026-10-16-calendar.sql has run.
        title = try c.decodeIfPresent(String.self, forKey: .title)
        place = try c.decodeIfPresent(String.self, forKey: .place)
        remind = try c.decodeIfPresent(Bool.self, forKey: .remind) ?? true
        cancelled = try c.decodeIfPresent(Bool.self, forKey: .cancelled) ?? false
        createdBy = try c.decodeIfPresent(UUID.self, forKey: .createdBy)
        squadIds = (try c.decodeIfPresent([SquadRow].self, forKey: .squads) ?? []).map(\.squadId)
    }

    init(id: UUID, clubId: UUID, seriesId: UUID?, startsAt: Date, endsAt: Date, title: String?, place: String?,
         remind: Bool = true, cancelled: Bool = false, createdBy: UUID? = nil, squadIds: [UUID] = []) {
        self.id = id
        self.clubId = clubId
        self.seriesId = seriesId
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.title = title
        self.place = place
        self.remind = remind
        self.cancelled = cancelled
        self.createdBy = createdBy
        self.squadIds = squadIds
    }

    /// What it is, as the calendar shows it: its own title, or "Practice".
    var displayTitle: String { title ?? "Practice" }
}
