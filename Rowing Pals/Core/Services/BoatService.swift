//
//  BoatService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Water sessions, their boats and saved boats (decisions 67, 70;
/// docs/migrations/2026-10-16-boats.sql). Coaches read their club's; a rower reads a sent boat
/// they're in. Every change goes through the database's functions, which check who's asking.
enum BoatService {
    /// A crew as the database takes it: `[{"seat": 1, "user": "<uuid>"}]`.
    nonisolated struct SeatParam: Encodable, Sendable {
        let seat: Int
        let user: UUID
    }

    private static let boatColumns = "*, session_boat_seats(seat, user_id)"
    private static let savedColumns = "*, saved_boat_seats(seat, user_id), session_boats(count)"

    // MARK: - Reading

    /// The club's water sessions starting on or after `from`, soonest first.
    static func sessions(from: Date) async throws -> [WaterSession] {
        guard let clubId = try await ViewerContext.shared.current().clubId else { return [] }
        return try await SupabaseService.shared
            .from("water_sessions").select().eq("club_id", value: clubId)
            .gte("starts_at", value: CalendarService.iso(from)).order("starts_at")
            .execute().value
    }

    /// The club's water sessions between two instants (the Calendar's month).
    static func sessions(from: Date, to: Date) async throws -> [WaterSession] {
        guard let clubId = try await ViewerContext.shared.current().clubId else { return [] }
        return try await SupabaseService.shared
            .from("water_sessions").select().eq("club_id", value: clubId)
            .gte("starts_at", value: CalendarService.iso(from)).lt("starts_at", value: CalendarService.iso(to))
            .order("starts_at").execute().value
    }

    /// The water session already planned from a practice or a race, if any.
    static func session(forPractice practiceId: UUID? = nil, event eventId: UUID? = nil) async throws -> WaterSession? {
        var query = SupabaseService.shared.from("water_sessions").select()
        if let practiceId { query = query.eq("practice_id", value: practiceId) }
        if let eventId { query = query.eq("event_id", value: eventId) }
        let rows: [WaterSession] = try await query.order("starts_at").limit(1).execute().value
        return rows.first
    }

    static func session(_ id: UUID) async throws -> WaterSession {
        try await SupabaseService.shared.from("water_sessions").select().eq("id", value: id).single().execute().value
    }

    /// Every boat of these sessions with its crew, in order.
    static func boats(ofSessions ids: [UUID]) async throws -> [SessionBoat] {
        guard !ids.isEmpty else { return [] }
        return try await SupabaseService.shared
            .from("session_boats").select(boatColumns).in("session_id", values: ids)
            .order("position").execute().value
    }

    static func boat(_ id: UUID) async throws -> SessionBoat {
        try await SupabaseService.shared.from("session_boats").select(boatColumns).eq("id", value: id).single().execute().value
    }

    static func savedBoats() async throws -> [SavedBoat] {
        guard let clubId = try await ViewerContext.shared.current().clubId else { return [] }
        return try await SupabaseService.shared
            .from("saved_boats").select(savedColumns).eq("club_id", value: clubId)
            .order("name").execute().value
    }

    static func savedBoat(_ id: UUID) async throws -> SavedBoat {
        try await SupabaseService.shared.from("saved_boats").select(savedColumns).eq("id", value: id).single().execute().value
    }

    /// The signed-in rower's next sent boat whose session hasn't started (their Feed), with its
    /// session; nil when there's none.
    static func myNextBoat(now: Date = Date()) async throws -> (boat: SessionBoat, session: WaterSession)? {
        struct Params: Encodable { let p_from: String }
        nonisolated struct Row: Decodable {
            let id: UUID
            let sessionId: UUID
            enum CodingKeys: String, CodingKey {
                case id
                case sessionId = "session_id"
            }
        }
        let rows: [Row] = try await SupabaseService.shared
            .rpc("my_boats", params: Params(p_from: CalendarService.iso(now))).execute().value
        guard let first = rows.first else { return nil }
        async let boatTask = boat(first.id)
        async let sessionTask = session(first.sessionId)
        return try await (boatTask, sessionTask)
    }

    // MARK: - Water sessions

    nonisolated struct SessionDraft: Sendable {
        var title: String
        var startsAt: Date
        var meetAt: String
        var plan: String
        var practiceId: UUID?
        var eventId: UUID?
    }

    /// Saves a session, new (`id` nil) or changed; returns its id.
    @discardableResult
    static func saveSession(id: UUID?, _ draft: SessionDraft) async throws -> UUID {
        struct Params: Encodable {
            let p_session: UUID?
            let p_title: String
            let p_starts_at: String
            let p_meet_at: String?
            let p_plan: String?
            let p_practice: UUID?
            let p_event: UUID?
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_session, forKey: .p_session)
                try c.encode(p_title, forKey: .p_title)
                try c.encode(p_starts_at, forKey: .p_starts_at)
                try c.encode(p_meet_at, forKey: .p_meet_at)
                try c.encode(p_plan, forKey: .p_plan)
                try c.encode(p_practice, forKey: .p_practice)
                try c.encode(p_event, forKey: .p_event)
            }
            enum Keys: String, CodingKey { case p_session, p_title, p_starts_at, p_meet_at, p_plan, p_practice, p_event }
        }
        return try await SupabaseService.shared.rpc("save_water_session", params: Params(
            p_session: id, p_title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            p_starts_at: CalendarService.iso(draft.startsAt), p_meet_at: trimmed(draft.meetAt), p_plan: trimmed(draft.plan),
            p_practice: draft.practiceId, p_event: draft.eventId
        )).execute().value
    }

    static func deleteSession(_ id: UUID) async throws {
        struct Params: Encodable { let p_session: UUID }
        try await SupabaseService.shared.rpc("delete_water_session", params: Params(p_session: id)).execute()
    }

    /// Sends every boat not sent yet; returns how many rowers were told.
    @discardableResult
    static func send(session id: UUID) async throws -> Int {
        struct Params: Encodable { let p_session: UUID }
        return try await SupabaseService.shared.rpc("send_water_session", params: Params(p_session: id)).execute().value
    }

    // MARK: - Boats

    nonisolated struct BoatDraft: Sendable {
        var name: String
        var boatType: BoatType
        var rigging: Rigging
        var seats: [BoatSeat]
    }

    /// Saves a boat in a session; a sent boat that changes goes back to Not sent.
    @discardableResult
    static func saveBoat(id: UUID?, session: UUID, _ draft: BoatDraft, keepSaved: Bool) async throws -> UUID {
        struct Params: Encodable {
            let p_boat: UUID?
            let p_session: UUID
            let p_name: String
            let p_type: String
            let p_rigging: String
            let p_seats: [SeatParam]
            let p_keep_saved: Bool
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_boat, forKey: .p_boat)
                try c.encode(p_session, forKey: .p_session)
                try c.encode(p_name, forKey: .p_name)
                try c.encode(p_type, forKey: .p_type)
                try c.encode(p_rigging, forKey: .p_rigging)
                try c.encode(p_seats, forKey: .p_seats)
                try c.encode(p_keep_saved, forKey: .p_keep_saved)
            }
            enum Keys: String, CodingKey { case p_boat, p_session, p_name, p_type, p_rigging, p_seats, p_keep_saved }
        }
        return try await SupabaseService.shared.rpc("save_session_boat", params: Params(
            p_boat: id, p_session: session, p_name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            p_type: draft.boatType.rawValue, p_rigging: draft.rigging.rawValue,
            p_seats: draft.seats.map { SeatParam(seat: $0.seat, user: $0.userId) }, p_keep_saved: keepSaved
        )).execute().value
    }

    static func deleteBoat(_ id: UUID) async throws {
        struct Params: Encodable { let p_boat: UUID }
        try await SupabaseService.shared.rpc("delete_session_boat", params: Params(p_boat: id)).execute()
    }

    /// Adds a saved boat to a session (anyone already in another of its boats is left out).
    @discardableResult
    static func add(savedBoat id: UUID, to session: UUID) async throws -> UUID {
        struct Params: Encodable { let p_saved: UUID; let p_session: UUID }
        return try await SupabaseService.shared.rpc("add_saved_boat", params: Params(p_saved: id, p_session: session)).execute().value
    }

    // MARK: - Saved boats

    @discardableResult
    static func saveSavedBoat(id: UUID?, _ draft: BoatDraft) async throws -> UUID {
        struct Params: Encodable {
            let p_saved: UUID?
            let p_name: String
            let p_type: String
            let p_rigging: String
            let p_seats: [SeatParam]
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_saved, forKey: .p_saved)
                try c.encode(p_name, forKey: .p_name)
                try c.encode(p_type, forKey: .p_type)
                try c.encode(p_rigging, forKey: .p_rigging)
                try c.encode(p_seats, forKey: .p_seats)
            }
            enum Keys: String, CodingKey { case p_saved, p_name, p_type, p_rigging, p_seats }
        }
        return try await SupabaseService.shared.rpc("save_saved_boat", params: Params(
            p_saved: id, p_name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            p_type: draft.boatType.rawValue, p_rigging: draft.rigging.rawValue,
            p_seats: draft.seats.map { SeatParam(seat: $0.seat, user: $0.userId) }
        )).execute().value
    }

    static func deleteSavedBoat(_ id: UUID) async throws {
        struct Params: Encodable { let p_saved: UUID }
        try await SupabaseService.shared.rpc("delete_saved_boat", params: Params(p_saved: id)).execute()
    }

    // MARK: - Who can go

    /// Who said they can go to a session (its practice's Available, or its race's yes) and who
    /// said they can't, with reasons; nil sets when the session has neither to check against.
    static func availability(of session: WaterSession) async throws -> (available: Set<UUID>, cant: [UUID: String?])? {
        if let practiceId = session.practiceId {
            let responses = try await CalendarService.responses(toPractices: [practiceId])
            var cant: [UUID: String?] = [:]
            for response in responses where response.answer == .cant { cant[response.userId] = response.reason }
            return (Set(responses.filter { $0.answer == .going }.map(\.userId)), cant)
        }
        if let eventId = session.eventId {
            let responses = try await CalendarService.eventResponses([eventId])
            var cant: [UUID: String?] = [:]
            for response in responses where !response.canCome { cant[response.userId] = response.reason }
            return (Set(responses.filter(\.canCome).map(\.userId)), cant)
        }
        return nil
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
