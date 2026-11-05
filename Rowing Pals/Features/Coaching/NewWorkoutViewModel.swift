//
//  NewWorkoutViewModel.swift
//  Rowing Pals
//

import Foundation

/// Setting or editing a land session (CoachWorkoutNew, decision 39; editing, user 2026-11-05):
/// everything a coach fills in, what the club offers to choose from (squads, rowing members, club
/// tests), and how many rowers it reaches. The pieces decide the reps; the title is written from
/// them until the coach types their own.
@Observable
final class NewWorkoutViewModel {
    /// The workout being edited; nil when setting a new one.
    let editingId: UUID?

    /// What the coach typed; empty while the title is written from the pieces.
    var customTitle = ""
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
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    /// A workout's test key, kept until the club's own tests have loaded to match it.
    private var pendingTestKey: String?

    init(editing workoutId: UUID? = nil) {
        editingId = workoutId
    }

    var isEditing: Bool { editingId != nil }

    /// Standard tests, then the club's own.
    var tests: [StandardTest] { StandardTest.all + clubTests.map(\.asTest) }

    /// The title written from the pieces ("4 × 500m"), or from the test.
    var autoTitle: String {
        if isTestDay, let test, pieces.isEmpty { return "\(test.label) test" }
        return WorkoutRules.piecesSummary(pieces) ?? ""
    }

    /// The title that's saved: the coach's own, else the one written from the pieces.
    var title: String {
        let typed = customTitle.trimmingCharacters(in: .whitespaces)
        return typed.isEmpty ? autoTitle : typed
    }

    /// How many rowers get it (and its alert).
    var recipientCount: Int {
        switch audience {
        case .club: rowers.count
        case .squads: squads.filter { squadIds.contains($0.id) }.reduce(into: Set<UUID>()) { $0.formUnion($1.memberIds) }
            .intersection(Set(rowers.map(\.id))).count
        case .rowers: rowerIds.count
        }
    }

    /// "Senior men, Novices" / "3 rowers" / "Whole club", for the For row.
    var audienceText: String {
        switch audience {
        case .club: return "Whole club"
        case .squads:
            let names = squads.filter { squadIds.contains($0.id) }.map(\.name)
            return names.isEmpty ? "Choose squads" : names.joined(separator: ", ")
        case .rowers:
            return rowerIds.isEmpty ? "Choose rowers" : (rowerIds.count == 1 ? "1 rower" : "\(rowerIds.count) rowers")
        }
    }

    /// Why Set or Save is unavailable, or nil.
    var problem: String? {
        if title.trimmingCharacters(in: .whitespaces).isEmpty { return "Add a piece, or give the session a title." }
        if isTestDay && test == nil { return "Choose the test." }
        if audience == .squads && squadIds.isEmpty { return "Choose at least one squad." }
        if audience == .rowers && rowerIds.isEmpty { return "Choose at least one rower." }
        return nil
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
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
            if let editingId { fill(from: try await WorkoutService.workout(editingId)) }
            if let key = pendingTestKey { test = self.tests.first { $0.key == key }; pendingTestKey = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Puts a workout's values in the form, for editing.
    private func fill(from workout: CoachWorkout) {
        let calendar = Calendar.current
        date = WorkoutRules.day(workout.workoutDate, calendar: calendar) ?? date
        if let start = workout.startTime {
            let parts = start.split(separator: ":").compactMap { Int($0) }
            if parts.count >= 2, let at = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date) {
                time = at
                hasTime = true
            }
        }
        description = workout.description ?? ""
        zone = workout.zone.flatMap(TrainingZone.init(rawValue:)) ?? .ut2
        pieces = workout.pieces
        isTestDay = workout.testKey != nil
        pendingTestKey = workout.testKey
        audience = workout.audience
        squadIds = Set(workout.squadIds)
        rowerIds = Set(workout.rowerIds)
        // Keep their own title; one that's just the pieces' own words stays written from them.
        customTitle = workout.title == WorkoutRules.piecesSummary(workout.pieces) ? "" : workout.title
    }

    /// Sets the workout, or saves the changes to it; true when it worked.
    @MainActor
    func save() async -> Bool {
        if let problem {
            errorMessage = problem
            return false
        }
        isSaving = true
        defer { isSaving = false }
        let draft = WorkoutService.Draft(
            title: title, date: date, startTime: hasTime ? time : nil, description: description,
            zone: zone, testKey: isTestDay ? test?.key : nil, pieces: pieces, audience: audience,
            squadIds: squadIds, rowerIds: rowerIds
        )
        do {
            if let editingId {
                try await WorkoutService.update(editingId, draft)
            } else {
                try await WorkoutService.create(draft)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
