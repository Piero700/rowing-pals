//
//  ShareCardRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The rows on a shared week card (decision 110).
struct ShareCardRulesTests {
    private static func calendar(_ start: WeekStart = .monday) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        calendar.firstWeekday = start.firstWeekday
        return calendar
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar().date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Monday 23 Nov to Monday 30 Nov 2026 (exclusive).
    private static let week = DateInterval(start: date(2026, 11, 23), end: date(2026, 11, 30))

    private static func practice(_ start: Date, title: String = "Land", cancelled: Bool = false,
                                 squads: [UUID] = []) -> Practice {
        Practice(id: UUID(), clubId: UUID(), seriesId: nil, startsAt: start,
                 endsAt: start.addingTimeInterval(5400), title: title, place: "Boathouse",
                 cancelled: cancelled, squadIds: squads)
    }

    private static func workout(_ day: String, audience: WorkoutAudience = .club, squads: [UUID] = []) -> CoachWorkout {
        CoachWorkout(id: UUID(), clubId: UUID(), createdBy: nil, title: "Steady", workoutDate: day,
                     startTime: "06:30:00", description: nil, zone: nil, testKey: nil,
                     pieces: [WorkoutPiece(kind: .distance, value: 2000, reps: 3, restMs: 300_000)],
                     audience: audience, squadIds: squads)
    }

    private static func water(_ start: Date, meet: String? = nil, practice: UUID? = nil) -> WaterSession {
        WaterSession(id: UUID(), clubId: UUID(), practiceId: practice, eventId: nil, title: "Water",
                     startsAt: start, meetAt: meet, plan: nil, createdBy: nil)
    }

    private static func rows(practices: [Practice] = [], workouts: [CoachWorkout] = [], water: [WaterSession] = [],
                             events: [ClubEvent] = [], audience: ShareAudience = .club) -> [ShareCardRow] {
        ShareCardRules.weekRows(practices: practices, workouts: workouts, water: water, events: events,
                                audience: audience, range: week, calendar: calendar())
    }

    @Test func rowsAreInTimeOrderAndSkipCancelled() {
        let result = Self.rows(
            practices: [Self.practice(Self.date(2026, 11, 25, 6, 30), cancelled: true)],
            workouts: [Self.workout("2026-11-24")],
            water: [Self.water(Self.date(2026, 11, 26, 6, 30), meet: "06:15")])
        let summary = WorkoutRules.piecesSummary(Self.workout("2026-11-24").pieces) ?? ""
        #expect(result.map(\.title) == ["Erg · \(summary)", "Water"])
        #expect(result[0].dayText == "Tue")
        #expect(result[0].timeText == "06:30")
        #expect(result[1].detail == "meet 06:15")
    }

    @Test func workoutDetailJoinsRateAndRest() {
        var piece = WorkoutPiece(kind: .distance, value: 2000, reps: 3, restMs: 300_000)
        piece.rateMin = 20
        piece.rateMax = 22
        let workout = CoachWorkout(id: UUID(), clubId: UUID(), createdBy: nil, title: "Steady",
                                   workoutDate: "2026-11-24", startTime: nil, description: nil, zone: nil,
                                   testKey: nil, pieces: [piece], audience: .club)
        let row = Self.rows(workouts: [workout])[0]
        #expect(row.detail == "20–22 · 5:00 rest")
        #expect(row.timeText == nil)
    }

    @Test func squadCardKeepsSquadAndWholeClubSessions() {
        let a = UUID(), b = UUID()
        let result = Self.rows(
            practices: [Self.practice(Self.date(2026, 11, 24, 7), squads: [a]),
                        Self.practice(Self.date(2026, 11, 25, 7), squads: [b]),
                        Self.practice(Self.date(2026, 11, 26, 7))],
            audience: .squad(a))
        #expect(result.count == 2)
    }

    @Test func waterFollowsItsLinkedPractice() {
        let a = UUID(), b = UUID()
        let forB = Self.practice(Self.date(2026, 11, 25, 7), squads: [b])
        let result = Self.rows(practices: [forB],
                               water: [Self.water(forB.startsAt, practice: forB.id),
                                       Self.water(Self.date(2026, 11, 27, 7))],
                               audience: .squad(a))
        #expect(result.map(\.title) == ["Water"])
        #expect(result[0].id.hasPrefix("water-"))
    }

    @Test func individualWorkoutsAreLeftOut() {
        #expect(Self.rows(workouts: [Self.workout("2026-11-24", audience: .rowers)]).isEmpty)
    }

    @Test func multiDayEventAppearsOnce() {
        let event = ClubEvent(id: UUID(), clubId: UUID(), kind: .race, name: "Head", firstDay: "2026-11-28",
                              lastDay: "2026-11-29", place: "Putney")
        let result = Self.rows(events: [event])
        #expect(result.count == 1)
        #expect(result[0].dayText == "Sat")
        #expect(result[0].timeText == nil)
        #expect(result[0].detail == "Putney")
    }

    @Test func theMondayAfterTheWeekIsNotOnThisCard() {
        let event = ClubEvent(id: UUID(), clubId: UUID(), kind: .race, name: "Head", firstDay: "2026-11-30",
                              lastDay: "2026-11-30")
        #expect(Self.rows(workouts: [Self.workout("2026-11-30")], events: [event]).isEmpty)
        #expect(Self.rows(practices: [Self.practice(Self.date(2026, 11, 30))]).isEmpty)
    }

    @Test func anEventFromBeforeTheWeekAppearsOnceOnItsFirstDayInRange() {
        let event = ClubEvent(id: UUID(), clubId: UUID(), kind: .race, name: "Camp", firstDay: "2026-11-21",
                              lastDay: "2026-11-24")
        let result = Self.rows(events: [event])
        #expect(result.count == 1)
        #expect(result[0].dayText == "Mon")
    }

    @Test func dateRangeFollowsWeekStart() {
        let day = Self.date(2026, 11, 24, 12)
        let monday = Self.calendar(.monday)
        let sunday = Self.calendar(.sunday)
        let mondayWeek = monday.dateInterval(of: .weekOfYear, for: day)!
        let sundayWeek = sunday.dateInterval(of: .weekOfYear, for: day)!
        #expect(ShareCardRules.dateRangeText(mondayWeek, calendar: monday) == "23–29 Nov")
        #expect(ShareCardRules.dateRangeText(sundayWeek, calendar: sunday) == "22–28 Nov")
        let across = DateInterval(start: Self.date(2026, 11, 28), end: Self.date(2026, 12, 5))
        #expect(ShareCardRules.dateRangeText(across, calendar: monday) == "28 Nov – 4 Dec")
    }

    @Test func busyWeekKeepsEveryRow() {
        let practices = (0..<12).map { Self.practice(Self.date(2026, 11, 23 + $0 % 7, 6 + $0)) }
        #expect(Self.rows(practices: practices).count == 12)
    }

    @Test func workoutRowsHaveOnePerPiece() {
        let rows = ShareCardRules.workoutRows(Self.workout("2026-11-24"))
        #expect(rows.count == 1)
        #expect(rows[0].title == "2,000m × 3")
        #expect(rows[0].detail == "5:00 rest")
        #expect(ShareCardRules.link != nil)
    }

    @Test func pieceDetailEndsWithTheRest() {
        var piece = WorkoutPiece(kind: .distance, value: 2000, reps: 3, restMs: 300_000)
        piece.rateMin = 26
        piece.rateMax = 28
        piece.splitMs = 102_000
        #expect(ShareCardRules.pieceDetail(piece) == "rate 26–28 · split 1:42 · 5:00 rest")
        #expect(ShareCardRules.pieceDetail(WorkoutPiece(kind: .time, value: 1_200_000, reps: 1)) == nil)
    }

    private static func dated(audience: WorkoutAudience, squads: [UUID] = [], zone: String? = nil,
                              testKey: String? = nil) -> CoachWorkout {
        CoachWorkout(id: UUID(), clubId: UUID(), createdBy: nil, title: "Steady", workoutDate: "2026-11-25",
                     startTime: "06:30:00", description: nil, zone: zone, testKey: testKey,
                     pieces: [], audience: audience, squadIds: squads)
    }

    @Test func workoutSubheadingNamesTheAudienceAndZone() {
        let men = UUID(), women = UUID()
        let names = [men: "Novice men", women: "Novice women"]
        let squad = Self.dated(audience: .squads, squads: [men], zone: "UT2")
        #expect(ShareCardRules.workoutSubheading(squad, clubName: "Test BC", squads: names, calendar: Self.calendar())
                == "Novice men · Wed 25 Nov · 06:30 · UT2")
        let both = Self.dated(audience: .squads, squads: [women, men])
        #expect(ShareCardRules.workoutSubheading(both, clubName: "Test BC", squads: names, calendar: Self.calendar())
                == "Novice men, Novice women · Wed 25 Nov · 06:30")
        let club = Self.dated(audience: .club, zone: "UT1")
        #expect(ShareCardRules.workoutSubheading(club, clubName: "Test BC", squads: names, calendar: Self.calendar())
                == "Test BC · Wed 25 Nov · 06:30 · UT1")
    }

    @Test func workoutSubheadingOnATestDayShowsAN() {
        let test = Self.dated(audience: .club, testKey: "2k")
        #expect(ShareCardRules.workoutSubheading(test, clubName: "Test BC", squads: [:], calendar: Self.calendar())
                == "Test BC · Wed 25 Nov · 06:30 · AN")
    }

    @Test func rowersWorkoutIsNamedByTheClubNotTheRowers() {
        let rowers = Self.dated(audience: .rowers)
        #expect(ShareCardRules.workoutAudience(rowers, clubName: "Test BC", squads: [:]) == "Test BC")
    }
}
