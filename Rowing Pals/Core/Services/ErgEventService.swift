//
//  ErgEventService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Erg events (decision 91; docs/migrations/2026-10-18-challenges-and-erg-events.sql): a set piece
/// rowed in a window, its board, the ones a new post can count for, and setting, changing or
/// deleting one (coaches, the owner, co-owners and admins, as the database checks).
enum ErgEventService {
    /// The signed-in rower's club's erg events, the latest first.
    static func events() async throws -> [ErgEvent] {
        guard let clubId = try await ViewerContext.shared.current().clubId else { return [] }
        return try await SupabaseService.shared
            .from("erg_events").select().eq("club_id", value: clubId)
            .order("starts_at", ascending: false).execute().value
    }

    static func event(_ id: UUID) async throws -> ErgEvent {
        try await SupabaseService.shared.from("erg_events").select().eq("id", value: id).single().execute().value
    }

    /// Each rower's best piece counted for it, in board order.
    static func board(of event: ErgEvent) async throws -> [ErgEventResult] {
        struct Params: Encodable { let p_event: UUID }
        let rows: [ErgEventResult] = try await SupabaseService.shared
            .rpc("erg_event_board", params: Params(p_event: event.id)).execute().value
        return ChallengeRules.eventBoard(rows, event: event)
    }

    /// The events a post made now could count for: from their start to six hours after their end.
    static func openForPosting(now: Date = Date()) async -> [ErgEvent] {
        guard let clubId = try? await ViewerContext.shared.current().clubId else { return [] }
        let rows: [ErgEvent]? = try? await SupabaseService.shared
            .from("erg_events").select().eq("club_id", value: clubId)
            .lte("starts_at", value: CalendarService.iso(now))
            .gte("ends_at", value: CalendarService.iso(now.addingTimeInterval(-ErgEvent.postingGrace)))
            .order("starts_at").execute().value
        return (rows ?? []).filter { $0.isOpenForPosting(at: now) }
    }

    nonisolated struct Draft: Sendable, Equatable {
        var title: String
        var distanceM: Int?
        var durationMs: Int?
        var startsAt: Date
        var endsAt: Date
    }

    /// Saves an erg event, new (`id` nil) or changed; returns its id.
    @discardableResult
    static func save(id: UUID?, _ draft: Draft) async throws -> UUID {
        struct Params: Encodable {
            let p_id: UUID?
            let p_title: String
            let p_distance_m: Int?
            let p_duration_ms: Int?
            let p_starts: String
            let p_ends: String
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_id, forKey: .p_id)
                try c.encode(p_title, forKey: .p_title)
                try c.encode(p_distance_m, forKey: .p_distance_m)
                try c.encode(p_duration_ms, forKey: .p_duration_ms)
                try c.encode(p_starts, forKey: .p_starts)
                try c.encode(p_ends, forKey: .p_ends)
            }
            enum Keys: String, CodingKey { case p_id, p_title, p_distance_m, p_duration_ms, p_starts, p_ends }
        }
        let id: UUID = try await SupabaseService.shared.rpc("save_erg_event", params: Params(
            p_id: id, p_title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            p_distance_m: draft.distanceM, p_duration_ms: draft.distanceM == nil ? draft.durationMs : nil,
            p_starts: CalendarService.iso(draft.startsAt), p_ends: CalendarService.iso(draft.endsAt)
        )).execute().value
        NotificationCenter.default.post(name: .challengesChanged, object: nil)
        return id
    }

    static func delete(_ id: UUID) async throws {
        struct Params: Encodable { let p_id: UUID }
        try await SupabaseService.shared.rpc("delete_erg_event", params: Params(p_id: id)).execute()
        NotificationCenter.default.post(name: .challengesChanged, object: nil)
    }
}
