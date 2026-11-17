//
//  ClubVerificationAdminService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Deciding clubs' verified tag in the app (decision 108). Only app admins — listed in
/// `app_admins`, which you edit in the SQL editor — can see the list or decide; the database refuses
/// anyone else (docs/migrations/2026-11-17-verification-admin.sql).
enum ClubVerificationAdminService {
    enum Decision: String, Encodable, Sendable {
        /// Gives the club the verified tag.
        case approve
        /// Turns the application down; the owner can apply again.
        case decline
        /// Takes the tag away again.
        case remove
    }

    /// Whether the signed-in account is an app admin. False when it can't be told (offline, or
    /// before the migration has run), so the admin screen simply doesn't show.
    static func isAdmin() async -> Bool {
        (try? await SupabaseService.shared.rpc("is_app_admin").execute().value as Bool) ?? false
    }

    /// Every application and every verified club, newest first.
    static func requests() async throws -> [ClubVerificationRequest] {
        try await SupabaseService.shared.rpc("admin_club_verifications").execute().value
    }

    static func decide(_ clubId: UUID, _ decision: Decision) async throws {
        struct Params: Encodable { let p_club: UUID; let p_decision: Decision }
        try await SupabaseService.shared
            .rpc("admin_decide_club_verification", params: Params(p_club: clubId, p_decision: decision))
            .execute()
    }
}
