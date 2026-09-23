//
//  PeopleListViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns one people list: someone's followers, someone's following, or the
/// Find rowers directory search (docs/design/rowing-pals-redesign-handoff-v2.md
/// §2 Screen 09). Every row's follow button state comes from one batched
/// query, not one per row.
@Observable
final class PeopleListViewModel {
    let kind: PeopleListKind

    var people: [PersonSummary] = []
    var states: [UUID: FollowState] = [:]
    var busyIds: Set<UUID> = []
    var viewerId: UUID?
    var isLoading = false
    var errorMessage: String?

    init(kind: PeopleListKind) {
        self.kind = kind
    }

    var title: String {
        switch kind {
        case .followers: "Followers"
        case .following: "Following"
        case .find: "Find rowers"
        }
    }

    var isSearchable: Bool {
        if case .find = kind { return true }
        return false
    }

    var emptyMessage: String {
        switch kind {
        case .followers: "No followers yet."
        case .following: "Not following anyone yet."
        case .find: "No rowers match that search."
        }
    }

    /// `query` only applies to Find rowers; the follower and following
    /// lists are already scoped to one person.
    @MainActor
    func load(query: String = "") async {
        isLoading = true
        defer { isLoading = false }
        do {
            viewerId = try await SupabaseService.shared.auth.session.user.id
            switch kind {
            case .followers(let userId):
                people = try await FollowService.followers(of: userId)
            case .following(let userId):
                people = try await FollowService.following(of: userId)
            case .find:
                people = try await FollowService.search(query)
            }
            states = try await FollowService.viewerStates()
            errorMessage = nil
        } catch {
            print("People list load failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func state(for id: UUID) -> FollowState {
        states[id] ?? .notFollowing
    }

    /// Follow, request, unfollow or cancel — whichever the row's current
    /// state calls for. Shows the database's real answer (a private rower
    /// becomes "Requested", not "Following").
    @MainActor
    func toggleFollow(_ id: UUID) async {
        guard !busyIds.contains(id) else { return }
        busyIds.insert(id)
        defer { busyIds.remove(id) }
        do {
            switch state(for: id) {
            case .notFollowing:
                states[id] = try await FollowService.follow(id)
            case .following, .requested:
                try await FollowService.unfollow(id)
                states[id] = .notFollowing
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
