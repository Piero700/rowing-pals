//
//  WaterSessionViewModel.swift
//  Rowing Pals
//

import Foundation

/// New or edit a water session (CoachWaterSessionNew, CoachAddBoat; decisions 67, 70): the title,
/// day and time, where to meet and the plan; its boats; adding a saved boat checked against who's
/// available, or a new one; and sending. The session is saved as soon as it needs to exist —
/// adding a boat, sending, or leaving the screen with a title.
@MainActor
@Observable
final class WaterSessionViewModel {
    private(set) var sessionId: UUID?
    private let seed: WaterSessionSeed

    var title = ""
    var day: Date
    var time: Date
    var meetAt = ""
    var plan = ""
    private(set) var practiceId: UUID?
    private(set) var eventId: UUID?

    private(set) var boats: [SessionBoat] = []
    private(set) var savedBoats: [SavedBoat] = []
    private(set) var names: [UUID: String] = [:]
    /// Who said they can go (nil without a practice or race to check against) and who can't.
    private(set) var available: Set<UUID>?
    private(set) var cant: Set<UUID> = []
    private(set) var isWorking = false
    private(set) var hasLoaded = false
    var errorMessage: String?
    private var savedDetails: String?
    private var isDeleted = false

    private var calendar: Calendar { .current }

    init(sessionId: UUID?, seed: WaterSessionSeed = WaterSessionSeed()) {
        self.sessionId = sessionId
        self.seed = seed
        let base = Calendar.current.startOfDay(for: seed.day ?? Date())
        day = base
        time = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: base) ?? base
        practiceId = seed.practiceId
        eventId = seed.eventId
    }

    var isNew: Bool { sessionId == nil }
    var startsAt: Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day) ?? day
    }
    var hasTitle: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Rowers in boats not sent yet: who Send tells.
    var unsentRowers: Int {
        Set(boats.filter { !$0.isSent }.flatMap { $0.seats.map(\.userId) }).count
    }

    /// "4 boats · 12 rowers".
    var summary: String {
        let rowers = Set(boats.flatMap { $0.seats.map(\.userId) }).count
        return "\(boats.count) boat\(boats.count == 1 ? "" : "s") · \(rowers) rower\(rowers == 1 ? "" : "s")"
    }

    /// "Sat 17 Oct · 07:00".
    var whenText: String {
        "\(CalendarRules.dayLabel(startsAt, calendar: calendar)) · \(CalendarRules.time(startsAt, calendar: calendar))"
    }

    /// "Sat 07:00 · you’re at stroke in M1 four", as the rower is told.
    var exampleAlert: String {
        let weekday = CalendarRules.weekdayShort(startsAt, calendar: calendar).capitalized
        let name = boats.first?.name ?? "M1 four"
        return "“\(weekday) \(CalendarRules.time(startsAt, calendar: calendar)) · you’re at stroke in \(name)”"
    }

    /// Who's in which boat already, for Add a boat.
    var seatedIn: [UUID: String] {
        var result: [UUID: String] = [:]
        for boat in boats { for seat in boat.seats { result[seat.userId] = boat.name } }
        return result
    }

    private var details: String { [title, meetAt, plan, CalendarService.iso(startsAt)].joined(separator: "|") }

    func load() async {
        do {
            async let membersTask = CalendarService.members()
            async let savedTask = BoatService.savedBoats()
            let (members, saved) = try await (membersTask, savedTask)
            names = Dictionary(members.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
            savedBoats = saved
            if let sessionId {
                let session = try await BoatService.session(sessionId)
                fill(from: session)
                boats = try await BoatService.boats(ofSessions: [sessionId])
                await loadAvailability(session)
            } else if !hasLoaded {
                try await prefill()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load the session. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    /// From a practice's "Plan boats" or a race's "Crew boats".
    private func prefill() async throws {
        if let practiceId = seed.practiceId {
            let practice = try await CalendarService.practice(practiceId)
            day = calendar.startOfDay(for: practice.startsAt)
            time = practice.startsAt
            title = practice.title ?? ""
            meetAt = practice.place ?? ""
            let responses = try await CalendarService.responses(toPractices: [practiceId])
            available = Set(responses.filter { $0.answer == .going }.map(\.userId))
            cant = Set(responses.filter { $0.answer == .cant }.map(\.userId))
        } else if let eventId = seed.eventId {
            let event = try await CalendarService.event(eventId)
            if let first = WorkoutRules.day(event.firstDay, calendar: calendar) {
                day = first
                time = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: first) ?? first
            }
            title = event.name
            meetAt = event.place ?? ""
            let responses = try await CalendarService.eventResponses([eventId])
            available = Set(responses.filter(\.canCome).map(\.userId))
            cant = Set(responses.filter { !$0.canCome }.map(\.userId))
        }
    }

    private func fill(from session: WaterSession) {
        guard savedDetails == nil else { return }
        title = session.title
        day = calendar.startOfDay(for: session.startsAt)
        time = session.startsAt
        meetAt = session.meetAt ?? ""
        plan = session.plan ?? ""
        practiceId = session.practiceId
        eventId = session.eventId
        savedDetails = details
    }

    private func loadAvailability(_ session: WaterSession) async {
        guard let result = try? await BoatService.availability(of: session) else {
            available = nil
            cant = []
            return
        }
        available = result.available
        cant = Set(result.cant.keys)
    }

    /// Saves the details if they changed (or the session doesn't exist yet) and returns its id.
    @discardableResult
    func ensureSaved() async -> UUID? {
        guard hasTitle else {
            errorMessage = "Give the session a title first."
            return nil
        }
        if let sessionId, savedDetails == details { return sessionId }
        do {
            let id = try await BoatService.saveSession(id: sessionId, BoatService.SessionDraft(
                title: title, startsAt: startsAt, meetAt: meetAt, plan: plan, practiceId: practiceId, eventId: eventId
            ))
            sessionId = id
            savedDetails = details
            // The database may have linked a practice at this time; pick up its answers.
            if let session = try? await BoatService.session(id) {
                practiceId = session.practiceId
                eventId = session.eventId
                await loadAvailability(session)
            }
            NotificationCenter.default.post(name: .boatsChanged, object: nil)
            errorMessage = nil
            return id
        } catch {
            errorMessage = "Couldn’t save the session. \(error.localizedDescription)"
            return nil
        }
    }

    /// Leaving the screen keeps what was typed, as long as it has a title.
    func saveOnLeaving() async {
        guard hasTitle, !isDeleted else { return }
        if sessionId != nil && savedDetails == details { return }
        await ensureSaved()
    }

    func add(_ saved: SavedBoat) async {
        isWorking = true
        defer { isWorking = false }
        guard let id = await ensureSaved() else { return }
        do {
            try await BoatService.add(savedBoat: saved.id, to: id)
            boats = try await BoatService.boats(ofSessions: [id])
            NotificationCenter.default.post(name: .boatsChanged, object: nil)
        } catch {
            errorMessage = "Couldn’t add the boat. \(error.localizedDescription)"
        }
    }

    func reloadBoats() async {
        guard let sessionId else { return }
        boats = (try? await BoatService.boats(ofSessions: [sessionId])) ?? boats
        savedBoats = (try? await BoatService.savedBoats()) ?? savedBoats
    }

    /// Sends every boat not sent yet; true when done.
    func send() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        guard let id = await ensureSaved() else { return false }
        do {
            try await BoatService.send(session: id)
            NotificationCenter.default.post(name: .boatsChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t send the boats. \(error.localizedDescription)"
            return false
        }
    }

    func delete() async -> Bool {
        guard let sessionId else {
            isDeleted = true
            return true
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await BoatService.deleteSession(sessionId)
            isDeleted = true
            NotificationCenter.default.post(name: .boatsChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t delete the session. \(error.localizedDescription)"
            return false
        }
    }
}
