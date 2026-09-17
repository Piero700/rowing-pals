//
//  ScopeResolver.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// The Following / My Club scope shown on the feed and every leaderboard —
/// one definition, since "what does My Club mean" needs exactly one answer
/// across all three screens that ask it.
///
/// Deliberately no Global case for now — the user asked to cancel it
/// ("maybe this will be for a v2 of the app") after finding it more scope
/// than they wanted right now, both here and on the post-visibility picker
/// (`PostVisibility`). Re-adding it later is a small, mechanical change in
/// both places; ripping out unused Global-handling code was judged better
/// than leaving it half-wired against a v2 that may or may not happen.
enum SocialScope: Int, CaseIterable {
    case following, myClub

    var label: String {
        switch self {
        case .following: "Following"
        case .myClub: "My Club"
        }
    }

    /// The exact, possibly-empty set of user ids this scope allows: empty
    /// for Following before anyone has followed anyone (task 16), or for
    /// My Club when the viewer's own profile has no club, rather than
    /// either of those silently falling back to showing everyone.
    func userIds() async throws -> [UUID] {
        switch self {
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
