//
//  AvailabilityViewModel.swift
//  Rowing Pals
//

import Foundation

/// Who's available (CoachAvailability; decision 68): this week's or next week's practices with how
/// many can and can't make each, then one session's Available (with side), Can't (with reasons)
/// and No answer lists, and the races coming up.
@MainActor
@Observable
final class AvailabilityViewModel {
    enum Week: Int { case this, next }

    var week: Week = .next {
        didSet { if week != oldValue { selectedId = nil; Task { await load() } } }
    }
    var selectedId: UUID?

    private(set) var weekStart: WeekStart = .monday
    private(set) var practices: [Practice] = []
    private(set) var audiences: [UUID: Set<UUID>] = [:]
    private(set) var responses: [UUID: [PracticeResponse]] = [:]
    private(set) var members: [ClubMember] = []
    private(set) var events: [ClubEvent] = []
    private(set) var eventAudiences: [UUID: Set<UUID>] = [:]
    private(set) var eventResponses: [UUID: [EventResponse]] = [:]
    private(set) var hasLoaded = false
    var errorMessage: String?

    var calendar: Calendar { weekStart.calendar() }

    var days: [Date] {
        let start = CalendarRules.weekStart(of: Date(), calendar: calendar)
        let first = week == .this ? start : (calendar.date(byAdding: .day, value: 7, to: start) ?? start)
        return CalendarRules.days(ofWeekStarting: first, calendar: calendar)
    }

    /// Everyone this week's practices are for.
    var everyone: Set<UUID> { audiences.values.reduce(into: Set<UUID>()) { $0.formUnion($1) } }

    var answeredCount: Int {
        let answered = Set(responses.values.flatMap { $0 }.filter { $0.answer != nil }.map(\.userId))
        return everyone.intersection(answered).count
    }

    /// "Mon 19 – Sun 25 Oct · 21 of 27 rowers have answered · All squads".
    var caption: String {
        guard let first = days.first, let last = days.last else { return "" }
        let range = "\(CalendarRules.dayLabel(first, calendar: calendar)) – \(CalendarRules.dayLabel(last, calendar: calendar))"
        guard !practices.isEmpty else { return range }
        return "\(range) · \(answeredCount) of \(everyone.count) rower\(everyone.count == 1 ? "" : "s") have answered · All squads"
    }

    var selected: Practice? {
        practices.first { $0.id == selectedId } ?? practices.first { $0.endsAt > Date() } ?? practices.first
    }

    func counts(for practice: Practice) -> CalendarRules.Counts {
        CalendarRules.counts(audience: audiences[practice.id] ?? [], responses: responses[practice.id] ?? [])
    }

    func audienceCount(for practice: Practice) -> Int { audiences[practice.id]?.count ?? 0 }

    /// "Mon 06:30".
    func glanceLabel(_ practice: Practice) -> String {
        "\(CalendarRules.dayLabel(practice.startsAt, calendar: calendar).split(separator: " ").first ?? "") \(CalendarRules.time(practice.startsAt, calendar: calendar))"
    }

    /// The selected session's three lists.
    func lists(for practice: Practice) -> (available: [AnswerListCard.Person], cant: [AnswerListCard.Person], none: [AnswerListCard.Person]) {
        let byUser = Dictionary((responses[practice.id] ?? []).map { ($0.userId, $0) }, uniquingKeysWith: { first, _ in first })
        let audience = audiences[practice.id] ?? []
        var available: [AnswerListCard.Person] = []
        var cant: [AnswerListCard.Person] = []
        var none: [AnswerListCard.Person] = []
        for member in members where audience.contains(member.id) {
            switch byUser[member.id]?.answer {
            case .going: available.append(.init(member: member, detail: member.side?.label))
            case .cant: cant.append(.init(member: member, detail: byUser[member.id]?.reason.map { "“\($0)”" }))
            case nil: none.append(.init(member: member, detail: nil))
            }
        }
        return (available, cant, none)
    }

    func counts(for event: ClubEvent) -> CalendarRules.Counts {
        CalendarRules.counts(audience: eventAudiences[event.id] ?? [], eventResponses: eventResponses[event.id] ?? [])
    }

    func load() async {
        weekStart = await CalendarService.weekStart()
        let days = self.days
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return }
        do {
            async let practicesTask = CalendarService.clubPractices(from: first, to: end)
            async let membersTask = CalendarService.members()
            async let eventsTask = CalendarService.clubEvents(fromDay: WorkoutRules.dayText(calendar.startOfDay(for: Date()), calendar: calendar))
            let (allPractices, members, allEvents) = try await (practicesTask, membersTask, eventsTask)
            let practices = allPractices.filter { !$0.cancelled }.sorted { $0.startsAt < $1.startsAt }
            let ids = practices.map(\.id)
            async let audiencesTask = CalendarService.audiences(ofPractices: ids)
            async let responsesTask = CalendarService.responses(toPractices: ids)
            let events = allEvents.filter(\.asksAvailability)
            let eventIds = events.map(\.id)
            async let eventAudiencesTask = CalendarService.audiences(ofEvents: eventIds)
            async let eventResponsesTask = CalendarService.eventResponses(eventIds)
            let (audiences, responses, eventAudiences, eventResponses) =
                try await (audiencesTask, responsesTask, eventAudiencesTask, eventResponsesTask)
            self.practices = practices
            self.members = members
            self.audiences = audiences
            self.responses = Dictionary(grouping: responses, by: \.practiceId)
            self.events = events
            self.eventAudiences = eventAudiences
            self.eventResponses = Dictionary(grouping: eventResponses, by: \.eventId)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load availability. \(error.localizedDescription)"
        }
        hasLoaded = true
    }
}
