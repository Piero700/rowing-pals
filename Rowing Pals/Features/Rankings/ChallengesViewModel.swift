//
//  ChallengesViewModel.swift
//  Rowing Pals
//

import Foundation

/// Rankings → Challenges (decision 91): the club's challenges and erg events, on now, coming up and
/// finished, with your own progress on each challenge that's on; and whether you can set them.
@MainActor
@Observable
final class ChallengesViewModel {
    /// A challenge or an erg event in the list.
    enum Item: Identifiable, Equatable {
        case challenge(Challenge)
        case event(ErgEvent)

        var id: UUID {
            switch self {
            case .challenge(let challenge): challenge.id
            case .event(let event): event.id
            }
        }
    }

    private(set) var challenges: [Challenge] = []
    private(set) var events: [ErgEvent] = []
    /// Everyone's metres in each challenge that's on.
    private(set) var standings: [UUID: [ChallengeStanding]] = [:]
    private(set) var squads: [Squad] = []
    private(set) var canSet = false
    private(set) var viewerId: UUID?
    private(set) var hasClub = true
    private(set) var hasLoaded = false
    var errorMessage: String?

    private var calendar: Calendar { .current }

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            viewerId = viewer.userId
            hasClub = viewer.clubId != nil
            async let challengesTask = ChallengeService.challenges()
            async let eventsTask = ErgEventService.events()
            async let canSetTask = ChallengeService.canSet()
            let (loadedChallenges, loadedEvents, allowed) = try await (challengesTask, eventsTask, canSetTask)
            challenges = loadedChallenges
            events = loadedEvents
            canSet = allowed
            let today = ChallengeRules.day(Date(), calendar: calendar)
            var found: [UUID: [ChallengeStanding]] = [:]
            for challenge in loadedChallenges where ChallengeRules.status(challenge, today: today) == .running {
                found[challenge.id] = (try? await ChallengeService.standings(of: challenge.id)) ?? []
            }
            standings = found
            if loadedChallenges.contains(where: { $0.kind == .squads }) {
                squads = (try? await ChallengeService.squads()) ?? []
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load challenges. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    var onNow: [Item] { items(.running) }
    var comingUp: [Item] { items(.upcoming) }
    var finished: [Item] { items(.finished) }

    private func items(_ status: ChallengeRules.Status) -> [Item] {
        let now = Date()
        let today = ChallengeRules.day(now, calendar: calendar)
        let shownChallenges = challenges.filter { ChallengeRules.status($0, today: today) == status }
        let shownEvents = events.filter { ChallengeRules.eventStatus($0, now: now) == status }
        let list = shownChallenges.map(Item.challenge) + shownEvents.map(Item.event)
        // On now and coming up: what ends or starts soonest first; finished: the most recent first.
        return list.sorted { a, b in
            switch status {
            case .upcoming: startKey(a) < startKey(b)
            case .running: endKey(a) < endKey(b)
            case .finished: endKey(a) > endKey(b)
            }
        }
    }

    private func startKey(_ item: Item) -> Date {
        switch item {
        case .challenge(let challenge): ChallengeRules.date(challenge.startsOn, calendar: calendar) ?? .distantFuture
        case .event(let event): event.startsAt
        }
    }

    private func endKey(_ item: Item) -> Date {
        switch item {
        case .challenge(let challenge):
            ChallengeRules.date(challenge.endsOn, calendar: calendar).map { calendar.date(byAdding: .day, value: 1, to: $0) ?? $0 } ?? .distantPast
        case .event(let event): event.endsAt
        }
    }

    // MARK: - Your progress on one that's on

    /// What the list says about you in a running challenge, with the bar's fill.
    func progress(in challenge: Challenge) -> (text: String, fraction: Double, isDone: Bool)? {
        guard let rows = standings[challenge.id] else { return nil }
        return ChallengeText.progress(in: challenge, standings: rows, squads: squads, viewerId: viewerId)
    }
}
