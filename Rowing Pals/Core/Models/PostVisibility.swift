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
///
/// `.following` is shown as **Friends** (decision 95, 2026-11-03): people who
/// follow each other. A one-way follower doesn't see it. The stored value stays
/// `following`, so posts already made keep their setting.
enum PostVisibility: String, Codable, CaseIterable {
    case following
    case club
    case everyone

    var label: String {
        switch self {
        case .following: "Friends"
        case .club: "My Club"
        case .everyone: "Everyone"
        }
    }
}
