//
//  ScopeResolver.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// The Following / My Club / Global scope shown on the feed and every
/// leaderboard — one definition, since "what does My Club mean" needs
/// exactly one answer across all three screens that ask it.
enum SocialScope: Int, CaseIterable {
    case following, myClub, global

    var label: String {
        switch self {
        case .following: "Following"
        case .myClub: "My Club"
        case .global: "Global"
        }
    }

    /// `nil` means no filter — every user qualifies (Global). A non-nil
    /// result is the exact, possibly-empty set of user ids this scope
    /// allows: empty for Following before anyone has followed anyone
    /// (task 16), or for My Club when the viewer's own profile has no
    /// club, rather than either of those silently falling back to Global.
    func userIds() async throws -> [UUID]? {
        switch self {
        case .global:
            return nil

        case .following:
            let userId = try await SupabaseService.shared.auth.session.user.id
            struct Row: Decodable {
                let followeeId: UUID
                enum CodingKeys: String, CodingKey { case followeeId = "followee_id" }
            }
            let rows: [Row] = try await SupabaseService.shared
                .from("follows")
                .select("followee_id")
                .eq("follower_id", value: userId)
                .execute()
                .value
            return rows.map(\.followeeId)

        case .myClub:
            let userId = try await SupabaseService.shared.auth.session.user.id
            let profile: Profile = try await SupabaseService.shared
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            guard let clubId = profile.clubId else { return [] }
            struct Row: Decodable { let id: UUID }
            let rows: [Row] = try await SupabaseService.shared
                .from("profiles")
                .select("id")
                .eq("club_id", value: clubId)
                .execute()
                .value
            return rows.map(\.id)
        }
    }
}
