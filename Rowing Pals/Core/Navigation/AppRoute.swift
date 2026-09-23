//
//  AppRoute.swift
//  Rowing Pals
//

import Foundation

/// Which list of people a `.people` route shows.
enum PeopleListKind: Hashable {
    case followers(UUID)
    case following(UUID)
    /// The Find rowers directory search.
    case find
}

/// Where a tap wants to go, described as plain data. Features raise a route
/// through the `navigate` environment action; `App/` is the only layer that
/// knows which screen each route becomes. This is how a post can open a
/// rower's profile without `Features/Feed` importing `Features/Profile`
/// (CLAUDE.md: no feature imports another feature).
enum AppRoute: Hashable, Identifiable {
    case profile(UUID)
    case people(PeopleListKind)
    case followRequests

    var id: Self { self }
}
