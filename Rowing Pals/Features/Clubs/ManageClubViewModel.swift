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
    var invitations: [ClubService.Person] = []
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

    @MainActor func newInviteCode() async {
        await perform { inviteCode = try await ClubService.inviteCode(regenerate: true) }
    }

    @MainActor func setRole(_ role: ClubRole, for person: ClubService.Person) async {
        await perform { try await ClubService.setRole(role, for: person.id) }
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
