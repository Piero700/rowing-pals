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
    /// One workout's detail screen.
    case post(UUID)
    /// Opens Log (capture) — handled by `RootView`, which owns that modal.
    case log
    /// Pick a club after onboarding without one (decision 24).
    case findClub
    /// "Your crew": your club, pending request, invitations and club options (v3 §12).
    case clubHub
    /// Create a club (you become its owner), or edit yours.
    case createClub
    case editClub
    /// Requests, invites, members, roles and ownership — admins and up (decision 25).
    case manageClub
    /// Coaching: the club's rowers, for its coaches (decisions 34, 39).
    case coaching
    /// One rower, as their coach sees them.
    case coachRower(UUID)
    /// The club's squads; and one squad to edit, or a new one (nil).
    case squads
    case squadEdit(UUID?)
    /// A rower's results at one test (a coach opening a test row).
    case pbHistory(StandardTest, UUID)

    var id: Self { self }
}
