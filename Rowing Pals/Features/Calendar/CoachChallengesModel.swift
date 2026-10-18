//
//  CoachChallengesModel.swift
//  Rowing Pals
//

import Foundation

/// The coach Calendar's challenges and erg events (decision 91): those on now and coming up, soonest
/// first, so a coach — who has no Rankings tab in the coach version — can follow and change them.
@MainActor
@Observable
final class CoachChallengesModel {
    enum Item: Identifiable {
        case challenge(Challenge)
        case event(ErgEvent)

        var id: UUID {
            switch self {
            case .challenge(let challenge): challenge.id
            case .event(let event): event.id
            }
        }
    }

    private(set) var items: [Item] = []

    func load() async {
        let calendar = Calendar.current
        let now = Date()
        let today = ChallengeRules.day(now, calendar: calendar)
        async let challengesTask = (try? await ChallengeService.challenges()) ?? []
        async let eventsTask = (try? await ErgEventService.events()) ?? []
        let (challenges, events) = await (challengesTask, eventsTask)
        let liveChallenges = challenges.filter { ChallengeRules.status($0, today: today) != .finished }
            .sorted { $0.startsOn < $1.startsOn }
        let liveEvents = events.filter { ChallengeRules.eventStatus($0, now: now) != .finished }
            .sorted { $0.startsAt < $1.startsAt }
        items = liveEvents.map(Item.event) + liveChallenges.map(Item.challenge)
    }
}
