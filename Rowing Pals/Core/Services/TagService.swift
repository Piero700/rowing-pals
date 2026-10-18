//
//  TagService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Crew tagging (decision 90; docs/migrations/2026-10-18-crew-tags.sql): who a post's author trained
/// with. The author sets the tags (clubmates who row); anyone tagged can take themselves off. Every
/// change goes through the database's functions, which check who's asking.
enum TagService {
    /// The tags on these posts, by post, in the order they were added. Whoever can see a post can
    /// see its tags.
    static func tags(of sessionIds: [UUID]) async throws -> [UUID: [SessionTag]] {
        guard !sessionIds.isEmpty else { return [:] }
        let rows: [SessionTag] = try await SupabaseService.shared
            .from("session_tags")
            .select("session_id, user_id, profiles(display_name)")
            .in("session_id", values: sessionIds)
            .order("created_at")
            .execute()
            .value
        return Dictionary(grouping: rows, by: \.sessionId)
    }

    /// Sets exactly who the author trained with (an empty list clears them).
    static func set(_ userIds: [UUID], on sessionId: UUID) async throws {
        struct Params: Encodable {
            let p_session: UUID
            let p_users: [UUID]
        }
        try await SupabaseService.shared.rpc("set_session_tags", params: Params(p_session: sessionId, p_users: userIds)).execute()
    }

    /// Takes the signed-in rower off a post they're tagged in.
    static func removeMe(from sessionId: UUID) async throws {
        struct Params: Encodable { let p_session: UUID }
        try await SupabaseService.shared.rpc("remove_my_tag", params: Params(p_session: sessionId)).execute()
    }

    /// Who can be tagged: the signed-in rower's clubmates who row, by name; empty without a club.
    static func clubmates() async throws -> [ClubMember] {
        let viewer = try await ViewerContext.shared.current()
        guard let clubId = viewer.clubId else { return [] }
        let people = try await ClubService.members(of: clubId)
        return people
            .filter { $0.isRower && $0.id != viewer.userId }
            .map { ClubMember(id: $0.id, displayName: $0.displayName) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
