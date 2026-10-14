//
//  WorkoutResultsViewModel.swift
//  Rowing Pals
//

import Foundation
import PaceEngine

/// One workout's results (CoachWorkoutResults, decisions 49 and 51): everyone it's for — done,
/// partly or not yet — and each rep's split against that rower's target.
@Observable
final class WorkoutResultsViewModel {
    struct RepCell: Identifiable {
        let id: Int
        /// Nil when the rep wasn't rowed.
        let splitMs: Int?
        let targetMs: Int?
    }

    struct Row: Identifiable {
        let rower: CoachRower
        let status: WorkoutStatus
        /// "Target 1:42.0 /500m · rate 26–28".
        let targetText: String
        let reps: [RepCell]
        var id: UUID { rower.id }
    }

    enum Filter: Int, CaseIterable {
        case all, done, notYet
    }

    let workoutId: UUID
    var workout: CoachWorkout?
    var audienceText = ""
    var rows: [Row] = []
    var filter: Filter = .all
    var isLoading = false
    var isDeleting = false
    var errorMessage: String?

    init(workoutId: UUID) {
        self.workoutId = workoutId
    }

    /// The day has gone: "not yet" reads "absent" (decision 57).
    var isOver: Bool {
        workout.map { WorkoutRules.isOver($0, today: WorkoutRules.dayText(Date(), calendar: .current)) } ?? false
    }

    var shownRows: [Row] {
        switch filter {
        case .all: rows
        case .done: rows.filter(\.status.isDone)
        case .notYet: rows.filter { !$0.status.isDone }
        }
    }

    var doneCount: Int { rows.filter(\.status.isDone).count }
    var partlyCount: Int { rows.filter { if case .partly = $0.status { true } else { false } }.count }
    /// Not yet on the day; absent after it (decision 57).
    var notYetCount: Int { rows.filter { $0.status == .notYet || $0.status == .absent }.count }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let workoutTask = WorkoutService.workout(workoutId)
            async let audienceTask = WorkoutService.audiences(of: [workoutId])
            async let sessionsTask = WorkoutService.linkedSessions(to: [workoutId])
            async let rosterTask = CoachingService.roster()
            let (workout, audiences, sessions, roster) = try await (workoutTask, audienceTask, sessionsTask, rosterTask)
            self.workout = workout
            let audience = audiences[workoutId] ?? []
            let squads = Dictionary(uniqueKeysWithValues: roster.squads.map { ($0.id, $0.name) })
            let names = Dictionary(uniqueKeysWithValues: roster.rowers.map { ($0.id, $0.displayName) })
            audienceText = WorkoutsText.audience(workout, squads: squads, names: names)

            let zone = WorkoutRules.zone(of: workout)
            let statuses = WorkoutService.statuses(for: workout, audience: audience, sessions: sessions)
            let pieceForRep = workout.pieces.flatMap { Array(repeating: $0, count: max(1, $0.reps)) }
            rows = roster.rowers
                .filter { audience.contains($0.id) }
                .map { rower in
                    let twoK = rower.prediction?.predictedSplitSeconds
                    let segments = sessions.filter { $0.userId == rower.id }.flatMap(\.segments)
                    let rowed = WorkoutRules.rowedReps(pieces: workout.pieces, segments: segments)
                    let reps = pieceForRep.enumerated().map { index, piece in
                        RepCell(
                            id: index,
                            splitMs: rowed.indices.contains(index) ? rowed[index]?.splitMs : nil,
                            targetMs: WorkoutRules.targetSplitMs(piece: piece, zone: zone, twoKSplitSeconds: twoK)
                        )
                    }
                    return Row(
                        rower: rower,
                        status: statuses[rower.id] ?? .notYet,
                        targetText: Self.targetText(workout: workout, zone: zone, twoK: twoK),
                        reps: reps
                    )
                }
                .sorted { a, b in
                    let order = { (status: WorkoutStatus) -> Int in
                        switch status {
                        case .done: 0
                        case .partly: 1
                        case .notYet: 2
                        case .absent: 3
                        }
                    }
                    if order(a.status) != order(b.status) { return order(a.status) < order(b.status) }
                    return a.rower.displayName.localizedCaseInsensitiveCompare(b.rower.displayName) == .orderedAscending
                }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The first piece's target for this rower, and the workout's rate band.
    private static func targetText(workout: CoachWorkout, zone: Tier.Name, twoK: Double?) -> String {
        var parts: [String] = []
        if let piece = workout.pieces.first,
           let target = WorkoutRules.targetSplitMs(piece: piece, zone: zone, twoKSplitSeconds: twoK) {
            parts.append("Target \(WorkoutRules.splitTenthsText(target)) /500m")
        } else if !workout.pieces.isEmpty {
            parts.append("No target yet: not enough sessions for a prediction")
        }
        if let rate = WorkoutRules.rateText(workout.pieces) { parts.append("rate \(rate)") }
        return parts.isEmpty ? "No target set" : parts.joined(separator: " · ")
    }

    /// Deletes the workout; true when it worked.
    @MainActor
    func delete() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await WorkoutService.delete(workoutId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
