//
//  WorkoutsViewModel.swift
//  Rowing Pals
//

import SwiftUI

/// Coaching's Workouts tab (CoachWorkouts, decision 39): the club's set workouts in Today,
/// Upcoming and Past, each with how many of its rowers have done it (decision 49).
@Observable
final class WorkoutsViewModel {
    struct Item: Identifiable {
        let workout: CoachWorkout
        let audienceText: String
        let done: Int
        let total: Int
        var id: UUID { workout.id }
    }

    var today: [Item] = []
    var upcoming: [Item] = []
    var past: [Item] = []
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    @MainActor
    func load(calendar: Calendar = .current) async {
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        do {
            let workouts = try await WorkoutService.clubWorkouts()
            let ids = workouts.map(\.id)
            async let audiencesTask = WorkoutService.audiences(of: ids)
            async let sessionsTask = WorkoutService.linkedSessions(to: ids)
            async let squadsTask = Self.squadNames()
            async let namesTask = Self.memberNames()
            let (audiences, sessions, squads, names) = try await (audiencesTask, sessionsTask, squadsTask, namesTask)

            let items = workouts.map { workout -> Item in
                let audience = audiences[workout.id] ?? []
                let statuses = WorkoutService.statuses(for: workout, audience: audience, sessions: sessions)
                return Item(
                    workout: workout,
                    audienceText: WorkoutsText.audience(workout, squads: squads, names: names),
                    done: statuses.values.filter(\.isDone).count,
                    total: audience.count
                )
            }
            let todayText = WorkoutRules.dayText(Date(), calendar: calendar)
            today = items.filter { WorkoutRules.section($0.workout, today: todayText) == .today }
                .sorted { ($0.workout.startTime ?? "") < ($1.workout.startTime ?? "") }
            upcoming = items.filter { WorkoutRules.section($0.workout, today: todayText) == .upcoming }
                .sorted { ($0.workout.workoutDate, $0.workout.startTime ?? "") < ($1.workout.workoutDate, $1.workout.startTime ?? "") }
            past = items.filter { WorkoutRules.section($0.workout, today: todayText) == .past }
                .sorted { ($0.workout.workoutDate, $0.workout.startTime ?? "") > ($1.workout.workoutDate, $1.workout.startTime ?? "") }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes a workout from a swipe on its card (decision 60): it leaves the list at once, and
    /// from its rowers' Feeds. On failure it stays, with the reason.
    @MainActor
    func delete(_ workoutId: UUID) async {
        do {
            try await WorkoutService.delete(workoutId)
            withAnimation {
                today.removeAll { $0.id == workoutId }
                upcoming.removeAll { $0.id == workoutId }
                past.removeAll { $0.id == workoutId }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func squadNames() async throws -> [UUID: String] {
        let viewer = try await ViewerContext.shared.current()
        guard let clubId = viewer.clubId else { return [:] }
        let squads = try await CoachingService.squads(of: clubId)
        return Dictionary(uniqueKeysWithValues: squads.map { ($0.id, $0.name) })
    }

    private static func memberNames() async throws -> [UUID: String] {
        let viewer = try await ViewerContext.shared.current()
        guard let clubId = viewer.clubId else { return [:] }
        let members = try await ClubService.members(of: clubId)
        return Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.displayName) })
    }
}
