//
//  ChallengeService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Club challenges (decision 91; docs/migrations/2026-10-18-challenges-and-erg-events.sql): the
/// club's challenges, everyone's metres in one, and setting, changing or deleting one — coaches,
/// the owner, co-owners and admins only, as the database checks.
enum ChallengeService {
    /// The signed-in rower's club's challenges, the latest-ending first.
    static func challenges() async throws -> [Challenge] {
        guard let clubId = try await ViewerContext.shared.current().clubId else { return [] }
        return try await SupabaseService.shared
            .from("challenges").select().eq("club_id", value: clubId)
            .order("ends_on", ascending: false).execute().value
    }

    static func challenge(_ id: UUID) async throws -> Challenge {
        try await SupabaseService.shared.from("challenges").select().eq("id", value: id).single().execute().value
    }

    /// Every rower in the club with their metres between the challenge's days.
    static func standings(of id: UUID) async throws -> [ChallengeStanding] {
        struct Params: Encodable { let p_challenge: UUID }
        return try await SupabaseService.shared
            .rpc("challenge_standings", params: Params(p_challenge: id)).execute().value
    }

    /// The club's squads, for a squad-vs-squad challenge.
    static func squads() async throws -> [Squad] {
        guard let clubId = try await ViewerContext.shared.current().clubId else { return [] }
        return try await CoachingService.squads(of: clubId)
    }

    /// Whether the signed-in member can set challenges and erg events in their club.
    static func canSet() async -> Bool {
        struct Params: Encodable { let p_club: UUID }
        guard let clubId = try? await ViewerContext.shared.current().clubId else { return false }
        let allowed: Bool? = try? await SupabaseService.shared
            .rpc("can_set_challenges", params: Params(p_club: clubId)).execute().value
        return allowed ?? false
    }

    nonisolated struct Draft: Sendable, Equatable {
        var kind: ChallengeKind
        var title: String
        var targetM: Int?
        var squadIds: [UUID]
        /// "yyyy-MM-dd".
        var startsOn: String
        var endsOn: String
    }

    /// Saves a challenge, new (`id` nil) or changed; returns its id.
    @discardableResult
    static func save(id: UUID?, _ draft: Draft) async throws -> UUID {
        struct Params: Encodable {
            let p_id: UUID?
            let p_kind: String
            let p_title: String
            let p_target_m: Int?
            let p_squads: [UUID]
            let p_starts: String
            let p_ends: String
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_id, forKey: .p_id)
                try c.encode(p_kind, forKey: .p_kind)
                try c.encode(p_title, forKey: .p_title)
                try c.encode(p_target_m, forKey: .p_target_m)
                try c.encode(p_squads, forKey: .p_squads)
                try c.encode(p_starts, forKey: .p_starts)
                try c.encode(p_ends, forKey: .p_ends)
            }
            enum Keys: String, CodingKey { case p_id, p_kind, p_title, p_target_m, p_squads, p_starts, p_ends }
        }
        let id: UUID = try await SupabaseService.shared.rpc("save_challenge", params: Params(
            p_id: id, p_kind: draft.kind.rawValue, p_title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            p_target_m: draft.kind == .squads ? nil : draft.targetM, p_squads: draft.kind == .squads ? draft.squadIds : [],
            p_starts: draft.startsOn, p_ends: draft.endsOn
        )).execute().value
        NotificationCenter.default.post(name: .challengesChanged, object: nil)
        return id
    }

    static func delete(_ id: UUID) async throws {
        struct Params: Encodable { let p_id: UUID }
        try await SupabaseService.shared.rpc("delete_challenge", params: Params(p_id: id)).execute()
        NotificationCenter.default.post(name: .challengesChanged, object: nil)
    }
}
