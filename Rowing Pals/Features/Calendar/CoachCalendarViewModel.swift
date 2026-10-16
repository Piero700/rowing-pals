//
//  CoachCalendarViewModel.swift
//  Rowing Pals
//

import Foundation

/// The coach's **Calendar** tab (CoachCalendar; decisions 39, 68, 69): a month in the club's
/// weeks with each day's practices and races marked, the chosen day's practices (with who's
/// available), land sessions and events, next week's availability, and the races coming up.
@MainActor
@Observable
final class CoachCalendarViewModel {
    private(set) var weekStart: WeekStart = .monday
    /// Any day in the month shown.
    var month = Date()
    var selectedDay = Calendar.current.startOfDay(for: Date())

    private(set) var practices: [Practice] = []
    private(set) var workouts: [CoachWorkout] = []
    private(set) var events: [ClubEvent] = []
    private(set) var squads: [Squad] = []
    private(set) var practiceAudiences: [UUID: Set<UUID>] = [:]
    private(set) var responses: [UUID: [PracticeResponse]] = [:]
    private(set) var eventAudiences: [UUID: Set<UUID>] = [:]
    private(set) var eventResponses: [UUID: [EventResponse]] = [:]
    /// Next week's practices, for the availability card.
    private(set) var nextWeekPractices: [Practice] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    var calendar: Calendar { weekStart.calendar() }
    var grid: [Date?] { CalendarRules.monthGrid(containing: month, calendar: calendar) }
    var today: Date { calendar.startOfDay(for: Date()) }

    /// The chosen day, and the next one when the chosen day is today (as the canvas shows).
    var shownDays: [Date] {
        let day = calendar.startOfDay(for: selectedDay)
        guard calendar.isDate(day, inSameDayAs: today), let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) else {
            return [day]
        }
        return [day, tomorrow]
    }

    func heading(for day: Date) -> String {
        let label = CalendarRules.dayLabel(day, calendar: calendar)
        if calendar.isDate(day, inSameDayAs: today) { return "Today · \(label)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow · \(label)"
        }
        return label
    }

    func practices(on day: Date) -> [Practice] {
        practices.filter { calendar.isDate($0.startsAt, inSameDayAs: day) }
    }

    func workouts(on day: Date) -> [CoachWorkout] {
        let text = WorkoutRules.dayText(day, calendar: calendar)
        return workouts.filter { $0.workoutDate == text }
    }

    func events(on day: Date) -> [ClubEvent] {
        let text = WorkoutRules.dayText(day, calendar: calendar)
        return events.filter { CalendarRules.event($0, covers: text) }
    }

    /// Practices drawn as dots under a day in the month (up to two).
    func dotCount(on day: Date) -> Int {
        min(practices(on: day).filter { !$0.cancelled }.count, 2)
    }

    func counts(for practice: Practice) -> CalendarRules.Counts {
        CalendarRules.counts(audience: practiceAudiences[practice.id] ?? [], responses: responses[practice.id] ?? [])
    }

    /// "Can race · can't · no answer" for an event.
    func counts(for event: ClubEvent) -> CalendarRules.Counts {
        let audience = eventAudiences[event.id] ?? []
        let answers = Dictionary((eventResponses[event.id] ?? []).map { ($0.userId, $0.canCome) }, uniquingKeysWith: { first, _ in first })
        var counts = CalendarRules.Counts()
        for user in audience {
            switch answers[user] {
            case true?: counts.available += 1
            case false?: counts.cant += 1
            case nil: counts.noAnswer += 1
            }
        }
        return counts
    }

    func squadText(for practice: Practice) -> String {
        guard !practice.squadIds.isEmpty else { return "Whole club" }
        let names = squads.filter { practice.squadIds.contains($0.id) }.map(\.name)
        return names.isEmpty ? "Squads" : names.joined(separator: ", ")
    }

    /// Races and events from today on (the "coming up" list).
    var upcomingEvents: [ClubEvent] {
        let text = WorkoutRules.dayText(today, calendar: calendar)
        return events.filter { $0.lastDay >= text }.prefix(3).map { $0 }
    }

    /// "21 of 27 rowers have answered. Tue 06:30 Water: 11 available." — or nil with nothing next week.
    var nextWeekSummary: String? {
        let open = nextWeekPractices.filter { !$0.cancelled }
        guard !open.isEmpty else { return nil }
        let everyone = open.reduce(into: Set<UUID>()) { $0.formUnion(practiceAudiences[$1.id] ?? []) }
        let answered = open.reduce(into: Set<UUID>()) { set, practice in
            set.formUnion((responses[practice.id] ?? []).filter { $0.answer != nil }.map(\.userId))
        }
        var text = "\(answered.count) of \(everyone.count) rower\(everyone.count == 1 ? "" : "s") have answered."
        if let lowest = open.min(by: { counts(for: $0).available < counts(for: $1).available }) {
            let when = "\(CalendarRules.weekdayShort(lowest.startsAt, calendar: calendar).capitalized) \(CalendarRules.time(lowest.startsAt, calendar: calendar))"
            text += " \(when) \(lowest.displayTitle): \(counts(for: lowest).available) available."
        }
        return text
    }

    func moveMonth(by months: Int) {
        month = calendar.date(byAdding: .month, value: months, to: month) ?? month
        Task { await load() }
    }

    func load() async {
        weekStart = await CalendarService.weekStart()
        let calendar = calendar
        let days = grid.compactMap { $0 }
        guard let first = days.first, let last = days.last else { return }
        let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: CalendarRules.weekStart(of: Date(), calendar: calendar)) ?? first
        let nextWeekEnd = calendar.date(byAdding: .day, value: 7, to: nextWeekStart) ?? nextWeekStart
        do {
            let viewer = try await ViewerContext.shared.current()
            async let monthPractices = CalendarService.clubPractices(from: first, to: end)
            async let weekPractices = CalendarService.clubPractices(from: nextWeekStart, to: nextWeekEnd)
            async let clubWorkouts = WorkoutService.clubWorkouts()
            async let clubEvents = CalendarService.clubEvents(fromDay: WorkoutRules.dayText(min(first, Date()), calendar: calendar))
            let (monthRows, weekRows, workoutRows, eventRows) = try await (monthPractices, weekPractices, clubWorkouts, clubEvents)
            if let clubId = viewer.clubId { squads = try await CoachingService.squads(of: clubId) }
            practices = monthRows
            nextWeekPractices = weekRows
            let firstText = WorkoutRules.dayText(first, calendar: calendar)
            let lastText = WorkoutRules.dayText(last, calendar: calendar)
            workouts = workoutRows.filter { $0.workoutDate >= firstText && $0.workoutDate <= lastText }
            events = eventRows
            let practiceIds = Array(Set((monthRows + weekRows).map(\.id)))
            async let audienceRows = CalendarService.audiences(ofPractices: practiceIds)
            async let responseRows = CalendarService.responses(toPractices: practiceIds)
            async let eventAudienceRows = CalendarService.audiences(ofEvents: eventRows.map(\.id))
            async let eventResponseRows = CalendarService.eventResponses(eventRows.map(\.id))
            let (audiences, answers, eventAudienceMap, eventAnswers) = try await (audienceRows, responseRows, eventAudienceRows, eventResponseRows)
            practiceAudiences = audiences
            responses = Dictionary(grouping: answers, by: \.practiceId)
            eventAudiences = eventAudienceMap
            eventResponses = Dictionary(grouping: eventAnswers, by: \.eventId)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load the calendar. \(error.localizedDescription)"
        }
        hasLoaded = true
    }
}
