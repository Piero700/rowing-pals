//
//  SquadsViewModel.swift
//  Rowing Pals
//

import Foundation

/// The club's squads and who's in them (CoachSquads, decision 39), for its coaches, owner and
/// co-owners. Also loads one squad for editing (CoachSquadEdit).
@Observable
final class SquadsViewModel {
    var squads: [Squad] = []
    /// The club's rowing members, alphabetical: who can be put in a squad.
    var rowers: [ClubService.Person] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let viewer = try await ViewerContext.shared.current()
            guard let clubId = viewer.clubId else {
                errorMessage = "You’re not in a club."
                return
            }
            async let squadsTask = CoachingService.squads(of: clubId)
            async let membersTask = ClubService.members(of: clubId)
            let (squads, members) = try await (squadsTask, membersTask)
            self.squads = squads
            rowers = members
                .filter(\.isRower)
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// "12 rowers · Joe Fenwick, Marcus Reilly, Nina Bergström and 9 more".
    func summary(_ squad: Squad) -> String {
        CoachingRules.squadSummary(memberNames: rowers.filter { squad.memberIds.contains($0.id) }.map(\.displayName))
    }

    /// Saves a new squad (nil id) or changes to one; true when it worked.
    @MainActor
    func save(id: UUID?, name: String, memberIds: Set<UUID>) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Give the squad a name."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            if let id, let existing = squads.first(where: { $0.id == id }) {
                if existing.name != trimmed { try await CoachingService.renameSquad(id, to: trimmed) }
                if existing.memberIds != memberIds { try await CoachingService.setMembers(memberIds, of: id) }
            } else {
                try await CoachingService.createSquad(name: trimmed, memberIds: memberIds)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func delete(_ id: UUID) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await CoachingService.deleteSquad(id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
