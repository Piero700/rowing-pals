//
//  ClubHubViewModel.swift
//  Rowing Pals
//

import Foundation

/// "Your crew" (v3 §12): the rower's club and role, a pending request, invitations, leaving.
@Observable
final class ClubHubViewModel {
    var membership: ClubService.Membership?
    var isLoading = false
    var isWorking = false
    var errorMessage: String?

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            membership = try await ClubService.membership()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func leave() async {
        await perform { try await ClubService.leave() }
    }

    @MainActor
    func cancelRequest() async {
        await perform { try await ClubService.cancelRequest() }
    }

    @MainActor
    func respond(to club: Club, accept: Bool) async {
        await perform { try await ClubService.respondToInvitation(from: club.id, accept: accept) }
    }

    /// Runs one change, shows its error if the server refused, then reloads (a reload never
    /// clears that error).
    @MainActor
    private func perform(_ change: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await change()
        } catch {
            errorMessage = error.localizedDescription
        }
        await load()
    }
}
