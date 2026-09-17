//
//  PostVisibility.swift
//  Rowing Pals
//

/// Mirrors the `post_visibility` enum in docs/schema.sql. Who can see a
/// post, chosen at post time — narrowest to widest.
enum PostVisibility: String, Codable, CaseIterable {
    case following
    case club
    case global

    var label: String {
        switch self {
        case .following: "Following"
        case .club: "My Club"
        case .global: "Global"
        }
    }
}
