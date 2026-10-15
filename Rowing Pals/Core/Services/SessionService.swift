//
//  SessionService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Deleting your own post (decision 63): `delete_session` takes it off that day's totals and
/// deletes it with everything hanging off it (docs/migrations/2026-10-15-delete-posts.sql), then
/// its photo files go from Storage. Everyone's feed, your profile and the leaderboards stop
/// showing it; a test result it set goes, so an earlier best is your PB again.
enum SessionService {
    /// The confirmation's message, wherever a post is deleted from.
    static let deleteWarning = "Its photos, splits, any test result, reactions and comments go too, and its metres come off your totals. This can't be undone."

    static func delete(_ sessionId: UUID) async throws {
        struct Params: Encodable { let p_session: UUID }
        let monitorPaths: [String] = try await SupabaseService.shared
            .rpc("delete_session", params: Params(p_session: sessionId))
            .execute().value
        NotificationCenter.default.post(name: .sessionDeleted, object: sessionId)

        // The post is gone either way; a file left behind is invisible and harmless, so this is
        // best-effort.
        let userId = try? await SupabaseService.shared.auth.session.user.id
        if !monitorPaths.isEmpty {
            _ = try? await SupabaseService.shared.storage.from("monitors").remove(paths: monitorPaths)
        }
        if let userId {
            let selfie = "\(userId.uuidString.lowercased())/\(sessionId.uuidString.lowercased()).jpg"
            _ = try? await SupabaseService.shared.storage.from("selfies").remove(paths: [selfie])
        }
    }
}
