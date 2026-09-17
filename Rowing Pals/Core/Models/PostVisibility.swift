//
//  PostVisibility.swift
//  Rowing Pals
//

/// Mirrors the `post_visibility` enum in docs/schema.sql. Who can see a
/// post, chosen at post time.
///
/// No Global case for now — cancelled after the first round of testing;
/// "maybe this will be for a v2 of the app." Re-adding it later just means
/// a new case here, a new case in `SocialScope`, and a new clause in
/// `FeedViewModel.resolvedVisibilityFilter()` — the query-filtering
/// approach it uses already generalises to a third tier without changing
/// shape, so nothing about this cut needs undoing beyond that.
enum PostVisibility: String, Codable, CaseIterable {
    case following
    case club

    var label: String {
        switch self {
        case .following: "Following"
        case .club: "My Club"
        }
    }
}
