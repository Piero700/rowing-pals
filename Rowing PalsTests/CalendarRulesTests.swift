//
//  CalendarRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The Calendar's arithmetic (decisions 39, 68, 69).
struct CalendarRulesTests {
    private static func calendar(_ start: WeekStart) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        calendar.firstWeekday = start.firstWeekday
        return calendar
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar(.monday).date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private static func practice(_ start: Date, minutes: Int = 90, series: Bool = false, cancelled: Bool = false) -> Practice {
        Practice(id: UUID(), clubId: UUID(), seriesId: series ? UUID() : nil, startsAt: start,
                 endsAt: start.addingTimeInterval(Double(minutes) * 60), title: "Water", place: "Boathouse", cancelled: cancelled)
    }

    // MARK: - Weeks and months (decision 69)

    @Test func theWeekStartsOnTheClubsDay() {
        let friday = Self.date(2026, 10, 16, 12)
        let monday = CalendarRules.weekStart(of: friday, calendar: Self.calendar(.monday))
        let sunday = CalendarRules.weekStart(of: friday, calendar: Self.calendar(.sunday))
        #expect(WorkoutRules.dayText(monday, calendar: Self.calendar(.monday)) == "2026-10-12")
        #expect(WorkoutRules.dayText(sunday, calendar: Self.calendar(.sunday)) == "2026-10-11")
        #expect(CalendarRules.days(ofWeekStarting: monday, calendar: Self.calendar(.monday)).count == 7)
    }

    @Test func aMondayIsTheStartOfItsOwnWeek() {
        let monday = Self.date(2026, 10, 19, 6, 30)
        let start = CalendarRules.weekStart(of: monday, calendar: Self.calendar(.monday))
        #expect(WorkoutRules.dayText(start, calendar: Self.calendar(.monday)) == "2026-10-19")
    }

    @Test func theMonthGridIsWholeWeeksFromTheClubsDay() {
        // 1 Oct 2026 is a Thursday: three blanks before it with Monday weeks, four with Sunday.
        let monday = CalendarRules.monthGrid(containing: Self.date(2026, 10, 16), calendar: Self.calendar(.monday))
        let sunday = CalendarRules.monthGrid(containing: Self.date(2026, 10, 16), calendar: Self.calendar(.sunday))
        #expect(monday.prefix(3).allSatisfy { $0 == nil } && monday[3] != nil)
        #expect(sunday.prefix(4).allSatisfy { $0 == nil } && sunday[4] != nil)
        #expect(monday.count % 7 == 0 && sunday.count % 7 == 0)
        #expect(monday.compactMap { $0 }.count == 31)
        #expect(CalendarRules.weekdayInitials(calendar: Self.calendar(.monday)).first == "M")
        #expect(CalendarRules.weekdayInitials(calendar: Self.calendar(.sunday)).first == "S")
    }

    // MARK: - Answers (decision 68)

    @Test func answersCloseWhenThePracticeStarts() {
        let start = Self.date(2026, 10, 20, 6, 30)
        let practice = Self.practice(start)
        #expect(CalendarRules.canAnswer(practice, now: start.addingTimeInterval(-60)))
        #expect(!CalendarRules.canAnswer(practice, now: start))
        #expect(!CalendarRules.canAnswer(Self.practice(start, cancelled: true), now: start.addingTimeInterval(-3600)))
    }

    @Test func checkInOpensHalfAnHourBefore() {
        let start = Self.date(2026, 10, 20, 6, 30)
        let practice = Self.practice(start, minutes: 90)
        #expect(!CalendarRules.canCheckIn(practice, now: start.addingTimeInterval(-31 * 60)))
        #expect(CalendarRules.canCheckIn(practice, now: start.addingTimeInterval(-30 * 60)))
        #expect(CalendarRules.canCheckIn(practice, now: start.addingTimeInterval(89 * 60)))
        #expect(!CalendarRules.canCheckIn(practice, now: start.addingTimeInterval(91 * 60)))
    }

    @Test func wholeDayIsAnAnswerOnlyWhenEverySessionShares_it() {
        #expect(CalendarRules.wholeDay([.going, .going]) == .going)
        #expect(CalendarRules.wholeDay([.cant]) == .cant)
        #expect(CalendarRules.wholeDay([.going, .cant]) == nil)
        #expect(CalendarRules.wholeDay([.going, nil]) == nil)
        #expect(CalendarRules.wholeDay([]) == nil)
    }

    @Test func theDaySummaryReadsLikeTheCanvas() {
        let calendar = Self.calendar(.monday)
        let morning = Self.practice(Self.date(2026, 10, 20, 6, 30))
        let evening = Self.practice(Self.date(2026, 10, 20, 18))
        #expect(CalendarRules.daySummary([(morning, nil), (evening, nil)], calendar: calendar) == "Not answered")
        #expect(CalendarRules.daySummary([(morning, .going), (evening, nil)], calendar: calendar) == "1 of 2 answered")
        #expect(CalendarRules.daySummary([(morning, .going), (evening, .going)], calendar: calendar) == "Both sessions")
        #expect(CalendarRules.daySummary([(morning, .cant), (evening, .going)], calendar: calendar) == "Evening only")
        #expect(CalendarRules.daySummary([(morning, .going), (evening, .cant)], calendar: calendar) == "Morning only")
        #expect(CalendarRules.daySummary([(morning, .cant), (evening, .cant)], calendar: calendar) == "Can’t make it")
        #expect(CalendarRules.daySummary([(morning, .going)], calendar: calendar) == "Available")
    }

    @Test func availableForTheRestSkipsAnsweredAndStartedSessions() {
        let now = Self.date(2026, 10, 18, 12)
        let past = Self.practice(Self.date(2026, 10, 18, 7))
        let answered = Self.practice(Self.date(2026, 10, 19, 6, 30))
        let open = Self.practice(Self.date(2026, 10, 20, 6, 30))
        let rest = CalendarRules.unanswered([past, answered, open], answers: [answered.id: .cant], now: now)
        #expect(rest.map(\.id) == [open.id])
    }

    // MARK: - The coach's counts and totals

    @Test func countsCoverEveryoneThePracticeIsFor() {
        let practice = Self.practice(Self.date(2026, 10, 20, 6, 30))
        let (a, b, c, d) = (UUID(), UUID(), UUID(), UUID())
        let responses = [
            PracticeResponse(practiceId: practice.id, userId: a, answer: .going, reason: nil, checkedInAt: nil),
            PracticeResponse(practiceId: practice.id, userId: b, answer: .cant, reason: "Lecture", checkedInAt: nil),
            PracticeResponse(practiceId: practice.id, userId: c, answer: nil, reason: nil, checkedInAt: nil),
        ]
        let counts = CalendarRules.counts(audience: [a, b, c, d], responses: responses)
        #expect(counts == CalendarRules.Counts(available: 1, cant: 1, noAnswer: 2))
    }

    @Test func excusedIsLeftOutOfTheTotal() {
        let totals = CalendarRules.totals([.present, .late, .absent, .excused, .present])
        #expect(totals.attended == 3)
        #expect(totals.counted == 4)
        #expect(totals.percentText == "75%")
        #expect(CalendarRules.totals([.excused]).percentText == nil)
    }

    @Test func aSeriesSaysWhichDayItRepeats() {
        let calendar = Self.calendar(.monday)
        #expect(CalendarRules.repeatCaption(Self.practice(Self.date(2026, 10, 16, 17, 30), series: true), calendar: calendar) == "every Friday")
        #expect(CalendarRules.repeatCaption(Self.practice(Self.date(2026, 10, 16, 17, 30)), calendar: calendar) == nil)
    }

    @Test func eventsCoverTheirDays() {
        let race = ClubEvent(id: UUID(), clubId: UUID(), kind: .race, name: "Head", firstDay: "2026-10-31", lastDay: "2026-11-01")
        #expect(CalendarRules.event(race, covers: "2026-10-31"))
        #expect(CalendarRules.event(race, covers: "2026-11-01"))
        #expect(!CalendarRules.event(race, covers: "2026-11-02"))
        #expect(CalendarRules.eventDays(race, calendar: Self.calendar(.monday)) == "Sat 31 Oct – Sun 1 Nov")
    }

    // MARK: - Register (decision 39)

    @Test func theRegisterStartsFromWhatTheRowerDid() {
        #expect(CalendarRules.startingMark(answer: .going, checkedIn: true, postedSession: false) == (.present, false))
        #expect(CalendarRules.startingMark(answer: nil, checkedIn: false, postedSession: true) == (.present, true))
        #expect(CalendarRules.startingMark(answer: .cant, checkedIn: false, postedSession: false) == (.excused, false))
        #expect(CalendarRules.startingMark(answer: .going, checkedIn: false, postedSession: false) == (.absent, false))
        #expect(CalendarRules.startingMark(answer: nil, checkedIn: false, postedSession: false).mark == nil)
    }

    @Test func eachRegisterRowSaysWhatTheRowerSaidAndDid() {
        let london = Self.calendar(.monday)
        #expect(CalendarRules.registerLine(answer: .going, reason: nil, checkedInAt: Self.date(2026, 10, 16, 17, 22),
                                           postedSession: true, calendar: london) == "Said available · checked in 17:22")
        #expect(CalendarRules.registerLine(answer: .cant, reason: "Exam tomorrow", checkedInAt: nil,
                                           postedSession: false, calendar: london) == "Can’t make it · “Exam tomorrow”")
        #expect(CalendarRules.registerLine(answer: nil, reason: nil, checkedInAt: nil,
                                           postedSession: true, calendar: london) == "No reply · posted a session today")
    }

    @Test func theLastChangeToAMarkIsShown() {
        let practice = UUID(), rower = UUID(), coach = UUID()
        let first = AttendanceMarkLogEntry(practiceId: practice, userId: rower, mark: .present, setBy: coach, setAt: Self.date(2026, 10, 16, 17, 40))
        let second = AttendanceMarkLogEntry(practiceId: practice, userId: rower, mark: .late, setBy: coach, setAt: Self.date(2026, 10, 16, 17, 45))
        #expect(CalendarRules.lastChange([first]) == nil)
        let change = CalendarRules.lastChange([second, first])
        #expect(change?.from == .present && change?.to.mark == .late)
    }

    // MARK: - Totals and terms

    @Test func attendanceIsCountedPerGroup() {
        let practice = UUID(), a = UUID(), b = UUID()
        let marks = [
            AttendanceMark(practiceId: practice, userId: a, mark: .present, setBy: nil, setAt: Date()),
            AttendanceMark(practiceId: UUID(), userId: a, mark: .excused, setBy: nil, setAt: Date()),
            AttendanceMark(practiceId: practice, userId: b, mark: .absent, setBy: nil, setAt: Date())
        ]
        #expect(CalendarRules.totals(marks, of: [a]) == CalendarRules.Totals(attended: 1, counted: 1))
        #expect(CalendarRules.totals(marks, of: [a, b]).percentText == "50%")
    }

    @Test func theTermHoldingTodayIsFound() {
        let autumn = ClubTerm(id: UUID(), name: "Autumn", startsOn: "2026-09-29", endsOn: "2026-12-05")
        let spring = ClubTerm(id: UUID(), name: "Spring", startsOn: "2027-01-12", endsOn: "2027-03-20")
        #expect(CalendarRules.term(containing: "2026-10-16", in: [autumn, spring]) == autumn)
        #expect(CalendarRules.term(containing: "2026-12-25", in: [autumn, spring]) == nil)
        #expect(CalendarRules.termText(autumn, calendar: Self.calendar(.monday)) == "Autumn · 29 Sep – 5 Dec")
    }

    @Test func aRaceCountsWhoCanRace() {
        let event = UUID(), a = UUID(), b = UUID(), c = UUID()
        let responses = [EventResponse(eventId: event, userId: a, canCome: true, reason: nil),
                         EventResponse(eventId: event, userId: b, canCome: false, reason: "Wedding")]
        let counts = CalendarRules.counts(audience: [a, b, c], eventResponses: responses)
        #expect(counts == CalendarRules.Counts(available: 1, cant: 1, noAnswer: 1))
    }

    @Test func practicesAddToWorkoutAttendance() {
        let rower = UUID()
        let marks = [AttendanceMark(practiceId: UUID(), userId: rower, mark: .late, setBy: nil, setAt: Date()),
                     AttendanceMark(practiceId: UUID(), userId: rower, mark: .absent, setBy: nil, setAt: Date()),
                     AttendanceMark(practiceId: UUID(), userId: rower, mark: .excused, setBy: nil, setAt: Date())]
        let result = CoachingRules.addingPractices(marks, to: [rower: WorkoutAttendance(attended: 3, set: 4)])
        #expect(result[rower] == WorkoutAttendance(attended: 4, set: 6))
    }

    @Test func coachingWeeksFollowTheClubsDay() {
        // Wednesday 21 Oct: three days have ended in a Sunday week, two in a Monday week.
        let wednesday = Self.date(2026, 10, 21, 12)
        #expect(CoachingRules.proRataTargetM(weeklyTargetM: 70_000, asOf: wednesday, calendar: Self.calendar(.monday)) == 20_000)
        #expect(CoachingRules.proRataTargetM(weeklyTargetM: 70_000, asOf: wednesday, calendar: Self.calendar(.sunday)) == 30_000)
    }

    // MARK: - Practice times (user, 2026-10-17)

    @Test func aPracticeEndsTwoHoursAfterItStarts() {
        let london = Self.calendar(.monday)
        let start = Self.date(2026, 10, 20, 17, 30)
        #expect(CalendarRules.time(CalendarRules.defaultEnd(after: start, calendar: london), calendar: london) == "19:30")
    }

    @Test func aLateStartEndsBeforeMidnight() {
        let london = Self.calendar(.monday)
        let start = Self.date(2026, 10, 20, 22, 45)
        let end = CalendarRules.defaultEnd(after: start, calendar: london)
        #expect(CalendarRules.time(end, calendar: london) == "23:59")
        #expect(london.isDate(end, inSameDayAs: start))
    }

    @Test func theEndCantBeBeforeTheStart() {
        let start = Self.date(2026, 10, 20, 6, 30)
        #expect(CalendarRules.earliestEnd(after: start) > start)
    }
}
