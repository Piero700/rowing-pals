//
//  CoachBoatsViewModel.swift
//  Rowing Pals
//

import Foundation

/// The coach's Boats tab (CoachBoats, CoachSavedBoats; decisions 67, 70): today's and upcoming
/// water sessions with their boats, who's going to the next one but not in a boat yet, and the
/// club's saved boats.
@MainActor
@Observable
final class CoachBoatsViewModel {
    enum Tab: Int { case sessions, saved }

    var tab: Tab = .sessions
    private(set) var sessions: [WaterSession] = []
    private(set) var boats: [UUID: [SessionBoat]] = [:]
    private(set) var savedBoats: [SavedBoat] = []
    private(set) var names: [UUID: String] = [:]
    /// The next session's rowers who said they can go but aren't in a boat.
    private(set) var unseated: (session: WaterSession, people: [ClubMember])?
    private(set) var hasLoaded = false
    var errorMessage: String?

    private var calendar: Calendar { .current }

    var today: [WaterSession] { sessions.filter { calendar.isDateInToday($0.startsAt) } }
    var upcoming: [WaterSession] { sessions.filter { !calendar.isDateInToday($0.startsAt) } }

    /// "4 boats · 12 rowers".
    func summary(of sessions: [WaterSession]) -> String {
        let all = sessions.flatMap { boats[$0.id] ?? [] }
        let rowers = Set(all.flatMap { $0.seats.map(\.userId) }).count
        return "\(all.count) boat\(all.count == 1 ? "" : "s") · \(rowers) rower\(rowers == 1 ? "" : "s")"
    }

    /// "Sat 17 Oct · 07:00".
    func when(_ session: WaterSession) -> String {
        "\(CalendarRules.dayLabel(session.startsAt, calendar: calendar)) · \(CalendarRules.time(session.startsAt, calendar: calendar))"
    }

    func load() async {
        do {
            let start = calendar.startOfDay(for: Date())
            async let sessionsTask = BoatService.sessions(from: start)
            async let savedTask = BoatService.savedBoats()
            async let membersTask = CalendarService.members()
            let (sessions, saved, members) = try await (sessionsTask, savedTask, membersTask)
            let boats = try await BoatService.boats(ofSessions: sessions.map(\.id))
            self.sessions = sessions
            self.boats = Dictionary(grouping: boats, by: \.sessionId)
            savedBoats = saved
            names = Dictionary(members.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
            unseated = try await unseatedPeople(next: sessions.first, members: members)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load boats. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    private func unseatedPeople(next: WaterSession?, members: [ClubMember]) async throws -> (WaterSession, [ClubMember])? {
        guard let next, let availability = try await BoatService.availability(of: next) else { return nil }
        let seated = Set((boats[next.id] ?? []).flatMap { $0.seats.map(\.userId) })
        let people = members.filter { availability.available.contains($0.id) && !seated.contains($0.id) }
        return people.isEmpty ? nil : (next, people)
    }
}
