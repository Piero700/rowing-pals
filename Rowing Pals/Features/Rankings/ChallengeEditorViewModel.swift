//
//  ChallengeEditorViewModel.swift
//  Rowing Pals
//

import Foundation

/// Set a challenge, or change or delete one (decision 91): its kind, name, the metres to aim for
/// (a personal target or a club total) or the squads racing, and its first and last days.
@MainActor
@Observable
final class ChallengeEditorViewModel {
    let challengeId: UUID?

    var kind: ChallengeKind = .target
    var title = ""
    /// Whole metres as typed.
    var targetText = ""
    var squadIds: Set<UUID> = []
    var startsOn = Calendar.current.startOfDay(for: Date()) {
        didSet { if endsOn < startsOn { endsOn = startsOn } }
    }
    var endsOn = Calendar.current.date(byAdding: .day, value: 29, to: Calendar.current.startOfDay(for: Date())) ?? Date()

    private(set) var squads: [Squad] = []
    private(set) var hasLoaded = false
    private(set) var isSaving = false
    var errorMessage: String?

    init(challengeId: UUID?) {
        self.challengeId = challengeId
    }

    var isNew: Bool { challengeId == nil }

    func load() async {
        squads = (try? await ChallengeService.squads()) ?? []
        if let challengeId {
            do {
                let challenge = try await ChallengeService.challenge(challengeId)
                kind = challenge.kind
                title = challenge.title
                targetText = challenge.targetM.map(String.init) ?? ""
                squadIds = Set(challenge.squadIds)
                startsOn = ChallengeRules.date(challenge.startsOn, calendar: .current) ?? startsOn
                endsOn = ChallengeRules.date(challenge.endsOn, calendar: .current) ?? endsOn
            } catch {
                errorMessage = "Couldn’t load the challenge. \(error.localizedDescription)"
            }
        }
        hasLoaded = true
    }

    var targetM: Int? { Int(targetText) }

    /// What's missing, in plain words; nil when it can be saved.
    var problem: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give the challenge a name." }
        switch kind {
        case .target, .clubTotal:
            guard let targetM, targetM >= 1000 else { return "Set the metres to aim for: 1,000 or more." }
        case .squads:
            if squads.count < 2 { return "Squad against squad needs two squads: make them in Squads first." }
            if squadIds.count < 2 { return "Choose at least two squads." }
        }
        if endsOn < startsOn { return "The challenge has to end on or after the day it starts." }
        if (Calendar.current.dateComponents([.day], from: startsOn, to: endsOn).day ?? 0) > 366 { return "A challenge can last up to a year." }
        return nil
    }

    func save() async -> Bool {
        guard problem == nil else { return false }
        isSaving = true
        defer { isSaving = false }
        let calendar = Calendar.current
        let draft = ChallengeService.Draft(
            kind: kind, title: title, targetM: targetM,
            squadIds: squads.map(\.id).filter { squadIds.contains($0) },
            startsOn: ChallengeRules.day(startsOn, calendar: calendar), endsOn: ChallengeRules.day(endsOn, calendar: calendar)
        )
        do {
            try await ChallengeService.save(id: challengeId, draft)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Couldn’t save the challenge. \(error.localizedDescription)"
            return false
        }
    }

    func delete() async -> Bool {
        guard let challengeId else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await ChallengeService.delete(challengeId)
            return true
        } catch {
            errorMessage = "Couldn’t delete the challenge. \(error.localizedDescription)"
            return false
        }
    }
}
