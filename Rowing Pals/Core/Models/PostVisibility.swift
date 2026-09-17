//
//  PostVisibility.swift
//  Rowing Pals
//

/// Mirrors the `post_visibility` enum in docs/schema.sql. Who can see a
/// post, chosen at post time.
///
/// No app-wide public option — cancelled after the first round of
/// testing; "maybe this will be for a v2 of the app." `.everyone` here
/// isn't that: it's the union of the other two (clubmates OR followers),
/// not every user of the app, added right after the cancellation because
/// there was no way to post to both circles in one go.
enum PostVisibility: String, Codable, CaseIterable {
    case following
    case club
    case everyone

    var label: String {
        switch self {
        case .following: "Following"
        case .club: "My Club"
        case .everyone: "Everyone"
        }
    }
}
