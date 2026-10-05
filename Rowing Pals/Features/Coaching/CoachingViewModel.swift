//
//  CoachingViewModel.swift
//  Rowing Pals
//

import Foundation

/// Coaching's Rowers list (CoachRowers, decisions 39 and 43): every rowing member of the club
/// the viewer coaches, filtered to one squad and sorted as chosen.
@Observable
final class CoachingViewModel {
    var roster: CoachingService.Roster?
    var squad: UUID?
    var sort: RosterSort = .behindTarget
    var isLoading = false
    var errorMessage: String?

    /// The list as shown: the chosen squad, in the chosen order.
    var rowers: [CoachRower] {
        CoachingRules.sorted(CoachingRules.filtered(roster?.rowers ?? [], squad: squad), by: sort)
    }

    var squadName: String {
        guard let squad, let found = roster?.squads.first(where: { $0.id == squad }) else { return "All squads" }
        return found.name
    }

    var behindCount: Int { rowers.filter(\.isBehindTarget).count }
    var flaggedCount: Int { rowers.filter { !$0.flags.isEmpty }.count }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await CoachingService.roster()
            roster = fresh
            // A squad deleted elsewhere drops back to everyone.
            if let squad, !fresh.squads.contains(where: { $0.id == squad }) { self.squad = nil }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
