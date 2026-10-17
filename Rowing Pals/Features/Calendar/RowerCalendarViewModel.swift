//
//  RowerCalendarViewModel.swift
//  Rowing Pals
//

import Foundation

/// The rower's Calendar (RowerCalendar; decision 68): this week or next, each day's sessions with
/// the rower's Available / Can't, the workouts set for them, and the races coming up with
/// "Can you race?". Answers save at once; a failed save puts the old answer back.
@MainActor
@Observable
final class RowerCalendarViewModel {
    enum Week: Int { case this, next }

    /// A water session on a day (decision 79), with the rower's boat and seat in it if they have one.
    struct WaterRow: Identifiable {
        let session: WaterSession
        let myBoat: SessionBoat?
        let mySeat: Int?
        /// Boats in it (the whole club's view; 0 when only the rower's own are loaded).
        let boatCount: Int
        var id: UUID { session.id }

        /// "You’re at stroke in M1 four", "3 boats", "No boats yet".
        var detail: String {
            if let myBoat, let mySeat {
                return "\(BoatRules.seatPhrase(mySeat, type: myBoat.boatType)) \(myBoat.name)"
            }
            if boatCount == 0 { return "No boats yet" }
            return boatCount == 1 ? "1 boat" : "\(boatCount) boats"
        }
    }

    var week: Week = .next {
        didSet { if week != oldValue { Task { await load() } } }
    }
    private(set) var weekStart: WeekStart = .monday
    private(set) var clubName: String?
    private(set) var practices: [Practice] = []
    private(set) var workouts: [CoachWorkout] = []
    private(set) var answers: [UUID: PracticeAnswer] = [:]
    private(set) var reasons: [UUID: String] = [:]
    private(set) var events: [ClubEvent] = []
    private(set) var eventAnswers: [UUID: Bool] = [:]
    /// Water sessions this week (decision 79): the rower's own, or the whole club's for those who
    /// chose it in Settings.
    private(set) var water: [WaterRow] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    var calendar: Calendar { weekStart.calendar() }

    var firstDay: Date {
        let thisWeek = CalendarRules.weekStart(of: Date(), calendar: calendar)
        return week == .this ? thisWeek : calendar.date(byAdding: .day, value: 7, to: thisWeek) ?? thisWeek
    }

    var days: [Date] { CalendarRules.days(ofWeekStarting: firstDay, calendar: calendar) }

    /// "Mon 19 – Sun 25 Oct".
    var rangeText: String {
        guard let first = days.first, let last = days.last else { return "" }
        return "\(CalendarRules.dayLabel(first, calendar: calendar)) – \(CalendarRules.dayLabel(last, calendar: calendar))"
    }

    /// The sessions still open to an answer this week, and how many have one.
    var openPractices: [Practice] { practices.filter { CalendarRules.canAnswer($0, now: Date()) } }
    var answeredCount: Int { openPractices.filter { answers[$0.id] != nil }.count }
    var restToAnswer: [Practice] { CalendarRules.unanswered(practices, answers: answers, now: Date()) }

    func practices(on day: Date) -> [Practice] {
        practices.filter { calendar.isDate($0.startsAt, inSameDayAs: day) }
    }

    func water(on day: Date) -> [WaterRow] {
        water.filter { calendar.isDate($0.session.startsAt, inSameDayAs: day) }
    }

    /// Workouts set for `day` that sit inside `practice`'s time.
    func workouts(during practice: Practice) -> [CoachWorkout] {
        workouts.filter { workout in
            guard let start = WorkoutRules.startDate(workout, calendar: calendar) else { return false }
            return start >= practice.startsAt && start < practice.endsAt
        }
    }

    /// Workouts on `day` that don't sit inside one of its practices.
    func otherWorkouts(on day: Date) -> [CoachWorkout] {
        let dayText = WorkoutRules.dayText(day, calendar: calendar)
        let sessions = practices(on: day)
        return workouts.filter { workout in
            workout.workoutDate == dayText && !sessions.contains { workouts(during: $0).contains(workout) }
        }
    }

    func load() async {
        weekStart = await CalendarService.weekStart()
        clubName = try? await ViewerContext.shared.current().clubName
        let first = firstDay
        let end = calendar.date(byAdding: .day, value: 7, to: first) ?? first
        do {
            async let practiceRows = CalendarService.myPractices(from: first, to: end)
            async let workoutRows = WorkoutService.mine(from: first, to: calendar.date(byAdding: .day, value: 6, to: first) ?? first, calendar: calendar)
            async let eventRows = CalendarService.myEvents(fromDay: WorkoutRules.dayText(Date(), calendar: calendar))
            let (loadedPractices, loadedWorkouts, loadedEvents) = try await (practiceRows, workoutRows, eventRows)
            practices = loadedPractices.filter { !$0.cancelled }
            workouts = loadedWorkouts
            events = loadedEvents
            async let responseRows = CalendarService.responses(toPractices: practices.map(\.id))
            async let eventResponseRows = CalendarService.eventResponses(events.map(\.id))
            let (responses, eventResponses) = try await (responseRows, eventResponseRows)
            let me = try? await ViewerContext.shared.current().userId
            answers = Dictionary(responses.filter { $0.userId == me }.compactMap { r in r.answer.map { (r.practiceId, $0) } },
                                 uniquingKeysWith: { first, _ in first })
            reasons = Dictionary(responses.filter { $0.userId == me }.compactMap { r in r.reason.map { (r.practiceId, $0) } },
                                 uniquingKeysWith: { first, _ in first })
            eventAnswers = Dictionary(eventResponses.filter { $0.userId == me }.map { ($0.eventId, $0.canCome) },
                                      uniquingKeysWith: { first, _ in first })
            // Before the boats migration there are none; the rest of the Calendar carries on.
            water = (try? await loadWater(from: first, to: end)) ?? []
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load your calendar. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    /// The week's water sessions: the sent boats the rower is in, or — for a coach, owner, co-owner
    /// or admin who chose Whole club in Settings — every water session in the club (decision 79).
    private func loadWater(from first: Date, to end: Date) async throws -> [WaterRow] {
        let viewer = try await ViewerContext.shared.current()
        let preferred = UserDefaults.standard.string(forKey: WaterCalendarScope.storageKey)
            .flatMap(WaterCalendarScope.init(rawValue:)) ?? .club
        let scope = WaterCalendarScope.resolved(preferred, isCoach: viewer.isCoach, clubRole: viewer.clubRole)
        switch scope {
        case .mine:
            return try await BoatService.myBoats(from: first)
                .filter { $0.session.startsAt < end }
                .map { pair in
                    WaterRow(session: pair.session, myBoat: pair.boat,
                             mySeat: pair.boat.seats.first { $0.userId == viewer.userId }?.seat, boatCount: 0)
                }
        case .club:
            let sessions = try await BoatService.sessions(from: first, to: end)
            let boats = try await BoatService.boats(ofSessions: sessions.map(\.id))
            return sessions.map { session in
                let inSession = boats.filter { $0.sessionId == session.id }
                let mine = inSession.first { boat in boat.seats.contains { $0.userId == viewer.userId } }
                return WaterRow(session: session, myBoat: mine,
                                mySeat: mine?.seats.first { $0.userId == viewer.userId }?.seat,
                                boatCount: inSession.count)
            }
        }
    }

    /// Answers one session. Can't keeps any reason given on the practice page.
    func answer(_ practice: Practice, _ answer: PracticeAnswer) async {
        await save([practice], answer: answer)
    }

    /// "Available for the other N".
    func answerRestAvailable() async {
        await save(restToAnswer, answer: .going)
    }

    func answer(_ event: ClubEvent, canCome: Bool) async {
        let old = eventAnswers[event.id]
        eventAnswers[event.id] = canCome
        do {
            try await CalendarService.respond(toEvent: event.id, canCome: canCome)
        } catch {
            eventAnswers[event.id] = old
            errorMessage = "Couldn’t save that. \(error.localizedDescription)"
        }
    }

    private func save(_ targets: [Practice], answer: PracticeAnswer) async {
        guard !targets.isEmpty else { return }
        let old = answers
        for practice in targets { answers[practice.id] = answer }
        do {
            for practice in targets {
                let reason = answer == .cant ? reasons[practice.id] : nil
                try await CalendarService.respond(to: practice.id, answer: answer, reason: reason)
            }
            errorMessage = nil
        } catch {
            answers = old
            errorMessage = "Couldn’t save that. \(error.localizedDescription)"
        }
    }
}
