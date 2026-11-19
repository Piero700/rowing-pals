//
//  ShareWeekViewModelTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The headings on the shared week / workout picture (decision 110).
@MainActor
struct ShareWeekViewModelTests {
    private static func calendar() -> Calendar {
        var calendar = WeekStart.monday.calendar(Calendar(identifier: .gregorian))
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return calendar
    }

    /// Thursday 19 November 2026.
    private static let today = calendar().date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 9)) ?? Date()

    private static func workout(_ id: UUID = UUID(), day: String = "2026-11-25") -> CoachWorkout {
        CoachWorkout(id: id, clubId: UUID(), createdBy: nil, title: "Steady 3 x 2k", workoutDate: day,
                     startTime: "06:30:00", description: nil, zone: nil, testKey: nil,
                     pieces: [WorkoutPiece(kind: .distance, value: 2000, reps: 3, restMs: 300_000)],
                     audience: .club, squadIds: [])
    }

    private static func model(_ mode: ShareWeekViewModel.Mode, squads: [Squad] = [],
                              workouts: [CoachWorkout] = []) -> ShareWeekViewModel {
        ShareWeekViewModel(mode: mode, practices: [], workouts: workouts, water: [], events: [],
                           squads: squads, clubName: "Test BC", today: today, weekStart: .monday,
                           calendar: calendar())
    }

    @Test func nextWeekHeadingAndDates() {
        let model = Self.model(.week)
        model.which = .nextWeek
        #expect(model.heading == "Next week")
        #expect(model.subheading.hasSuffix("23–29 Nov"))
    }

    @Test func squadNameInSubheading() {
        let squad = Squad(id: UUID(), name: "Novice men", memberIds: [])
        let model = Self.model(.week, squads: [squad])
        model.audience = .squad(squad.id)
        #expect(model.subheading.hasPrefix("Novice men · "))
    }

    @Test func workoutModeUsesWorkoutTitle() {
        let workout = Self.workout()
        let model = Self.model(.workout(workout.id), workouts: [workout])
        #expect(model.heading == "Steady 3 x 2k")
        #expect(model.subheading == "Wed 25 Nov · 06:30")
        #expect(model.rows.count == 1)
    }
}
