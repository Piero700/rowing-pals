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
        // From the shared viewer context: fetched once, not again on every screen.
        let viewer = try await ViewerContext.shared.current()
        switch self {
        case .following: return viewer.followingIds
        case .myClub: return viewer.clubmateIds
        }
    }
}
