//
//  ClubHubViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// "Your crew" (v3 §12, decisions 25–26): the rower's club with every member, or — without a
/// club — their join request (waiting or declined), invitations and ways to find or create one.
@Observable
final class ClubHubViewModel {
    var membership: ClubService.Membership?
    var members: [ClubService.Person] = []
    var myId: UUID?
    var isLoading = false
    var isWorking = false
    var errorMessage: String?
    /// Set when a request this screen was waiting on is accepted, so the screen closes and the
    /// rower lands back where they started, now in the club.
    var wasAccepted = false

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        let wasWaiting = membership?.club == nil && membership?.request?.isDeclined == false
        do {
            myId = try? await SupabaseService.shared.auth.session.user.id
            let fresh = try await ClubService.membership()
            if let clubId = fresh.club?.id {
                members = try await ClubService.members(of: clubId)
            } else {
                members = []
            }
            membership = fresh
            if wasWaiting, fresh.club != nil {
                wasAccepted = true
                NotificationCenter.default.post(name: .rowerClubChanged, object: nil)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor func leave() async {
        await perform { try await ClubService.leave() }
    }

    /// Takes back a waiting request, or clears a declined one.
    @MainActor func cancelRequest() async {
        await perform { try await ClubService.cancelRequest() }
    }

    /// After a decline: ask the same club again.
    @MainActor func requestAgain(_ club: Club) async {
        await perform { _ = try await ClubService.join(club.id) }
    }

    @MainActor func respond(to club: Club, accept: Bool) async {
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
