//
//  NewWorkoutViewModel.swift
//  Rowing Pals
//

import Foundation

/// New workout (CoachWorkoutNew, decision 39): everything a coach fills in, what the club
/// offers to choose from (squads, rowing members, club tests), and how many rowers it will reach.
@Observable
final class NewWorkoutViewModel {
    var title = ""
    var date = Date()
    var hasTime = false
    var time: Date = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()) ?? Date()
    var description = ""
    var zone: TrainingZone = .ut2
    var pieces: [WorkoutPiece] = []
    var isTestDay = false
    var test: StandardTest?
    var audience: WorkoutAudience = .club
    var squadIds: Set<UUID> = []
    var rowerIds: Set<UUID> = []

    var squads: [Squad] = []
    /// The club's rowing members, alphabetical.
    var rowers: [ClubService.Person] = []
    var clubTests: [ClubTest] = []
    var isSaving = false
    var errorMessage: String?

    /// Standard tests, then the club's own.
    var tests: [StandardTest] { StandardTest.all + clubTests.map(\.asTest) }

    /// How many rowers get it (and its alert).
    var recipientCount: Int {
        switch audience {
        case .club: rowers.count
        case .squads: squads.filter { squadIds.contains($0.id) }.reduce(into: Set<UUID>()) { $0.formUnion($1.memberIds) }
            .intersection(Set(rowers.map(\.id))).count
        case .rowers: rowerIds.count
        }
    }

    /// Why Set workout is unavailable, or nil.
    var problem: String? {
        if title.trimmingCharacters(in: .whitespaces).isEmpty { return "Give the workout a title." }
        if isTestDay && test == nil { return "Choose the test." }
        if audience == .squads && squadIds.isEmpty { return "Choose at least one squad." }
        if audience == .rowers && rowerIds.isEmpty { return "Choose at least one rower." }
        return nil
    }

    @MainActor
    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            guard let clubId = viewer.clubId else { return }
            async let squadsTask = CoachingService.squads(of: clubId)
            async let membersTask = ClubService.members(of: clubId)
            async let testsTask = try? await ClubTestService.mine()
            let (squads, members, tests) = try await (squadsTask, membersTask, testsTask)
            self.squads = squads
            rowers = members.filter(\.isRower)
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            clubTests = tests?.tests ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sets the workout; true when it worked.
    @MainActor
    func save() async -> Bool {
        if let problem {
            errorMessage = problem
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await WorkoutService.create(WorkoutService.Draft(
                title: title, date: date, startTime: hasTime ? time : nil, description: description,
                zone: zone, testKey: isTestDay ? test?.key : nil, pieces: pieces, audience: audience,
                squadIds: squadIds, rowerIds: rowerIds
            ))
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
