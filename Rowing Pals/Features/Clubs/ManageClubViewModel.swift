//
//  ManageClubViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Manage club (decision 25): the club, your role, join requests, invitations, the invite
/// code, members and roles, and ownership. Every change is checked again by the server, which
/// says why when it refuses.
@Observable
final class ManageClubViewModel {
    var club: Club?
    var myRole: ClubRole = .member
    var myId: UUID?
    var members: [ClubService.Person] = []
    var requests: [ClubService.Person] = []
    /// Waiting and declined invitations (decision 26).
    var invitations: [ClubService.Invitation] = []
    var inviteCode: String?
    var isLoading = false
    var isWorking = false
    var errorMessage: String?
    /// Set when the club is gone (deleted) or you've left, so the screen closes.
    var isFinished = false

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            myId = try await SupabaseService.shared.auth.session.user.id
            let membership = try await ClubService.membership()
            club = membership.club
            myRole = membership.role
            guard let clubId = membership.club?.id, membership.role.canManageMembers else {
                isFinished = membership.club == nil
                return
            }
            async let members = ClubService.members(of: clubId)
            async let requests = ClubService.requests(for: clubId)
            async let invitations = ClubService.invitations(for: clubId)
            async let code = ClubService.inviteCode()
            (self.members, self.requests, self.invitations) = try await (members, requests, invitations)
            inviteCode = try? await code
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Owner first, then co-owners, admins and members — everyone but you, for handing over.
    var otherMembers: [ClubService.Person] {
        members.filter { $0.id != myId }
    }

    @MainActor func respond(to person: ClubService.Person, accept: Bool) async {
        await perform { try await ClubService.respondToRequest(from: person.id, accept: accept) }
    }

    @MainActor func withdrawInvitation(to person: ClubService.Person) async {
        await perform { try await ClubService.withdrawInvitation(to: person.id) }
    }

    /// After a decline: send the invitation again.
    @MainActor func inviteAgain(_ person: ClubService.Person) async {
        await perform { try await ClubService.invite(person.id) }
    }

    @MainActor func newInviteCode() async {
        await perform { inviteCode = try await ClubService.inviteCode(regenerate: true) }
    }

    /// The member sheet's Done: a new role, coaching on or off, or both.
    @MainActor func save(role: ClubRole?, isCoach: Bool?, for person: ClubService.Person) async {
        guard role != nil || isCoach != nil else { return }
        await perform {
            if let role { try await ClubService.setRole(role, for: person.id) }
            if let isCoach { try await ClubService.setCoach(isCoach, for: person.id) }
        }
    }

    @MainActor func remove(_ person: ClubService.Person) async {
        await perform { try await ClubService.remove(person.id) }
    }

    @MainActor func transferOwnership(to person: ClubService.Person) async {
        await perform { try await ClubService.transferOwnership(to: person.id) }
    }

    @MainActor func deleteClub() async {
        await perform { try await ClubService.deleteClub() }
    }

    @MainActor func leave() async {
        await perform { try await ClubService.leave() }
    }

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
