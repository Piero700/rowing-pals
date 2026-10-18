//
//  ChallengeDetailViewModel.swift
//  Rowing Pals
//

import Foundation

/// One challenge's page (decision 91): the challenge, everyone's metres in it and, for squad against
/// squad, the squads; worked out by kind with `ChallengeRules`.
@MainActor
@Observable
final class ChallengeDetailViewModel {
    let challengeId: UUID

    private(set) var challenge: Challenge?
    private(set) var standings: [ChallengeStanding] = []
    private(set) var squads: [Squad] = []
    private(set) var canEdit = false
    private(set) var viewerId: UUID?
    private(set) var hasLoaded = false
    var errorMessage: String?

    init(challengeId: UUID) {
        self.challengeId = challengeId
    }

    func load() async {
        do {
            viewerId = try await ViewerContext.shared.current().userId
            async let challengeTask = ChallengeService.challenge(challengeId)
            async let standingsTask = ChallengeService.standings(of: challengeId)
            async let canEditTask = ChallengeService.canSet()
            let (loaded, rows, allowed) = try await (challengeTask, standingsTask, canEditTask)
            challenge = loaded
            standings = rows
            canEdit = allowed
            if loaded.kind == .squads {
                squads = try await ChallengeService.squads()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load the challenge. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    var targetRows: [ChallengeRules.TargetRow] {
        guard let target = challenge?.targetM else { return [] }
        return ChallengeRules.targetRows(standings, target: target)
    }

    var doneCount: Int { targetRows.filter(\.isDone).count }

    var total: Int { ChallengeRules.clubTotal(standings) }

    var contributors: [ChallengeStanding] { ChallengeRules.contributors(standings) }

    var squadRows: [ChallengeRules.SquadRow] {
        guard let challenge else { return [] }
        return ChallengeRules.squadRows(standings, squads: squads, ids: challenge.squadIds)
    }

    var myMetres: Int { standings.first { $0.userId == viewerId }?.metres ?? 0 }

    /// The viewer rows in the club (a coach-only account isn't in the standings).
    var viewerRows: Bool { standings.contains { $0.userId == viewerId } }
}
