//
//  FeedChallengesModel.swift
//  Rowing Pals
//

import Foundation

/// The Feed's challenge cards (decision 91): each challenge that's on, with your progress; and each
/// erg event that's on, starts today, or can still take a piece rowed in it.
@MainActor
@Observable
final class FeedChallengesModel {
    enum Item: Identifiable {
        case challenge(Challenge, progress: (text: String, fraction: Double, isDone: Bool)?)
        case event(ErgEvent)

        var id: UUID {
            switch self {
            case .challenge(let challenge, _): challenge.id
            case .event(let event): event.id
            }
        }
    }

    private(set) var items: [Item] = []

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            guard viewer.clubId != nil, viewer.isRower else {
                items = []
                return
            }
            let calendar = Calendar.current
            let now = Date()
            let today = ChallengeRules.day(now, calendar: calendar)
            async let challengesTask = ChallengeService.challenges()
            async let eventsTask = ErgEventService.events()
            let (challenges, events) = try await (challengesTask, eventsTask)
            let running = challenges.filter { ChallengeRules.status($0, today: today) == .running }
                .sorted { $0.endsOn < $1.endsOn }
            let squads = running.contains { $0.kind == .squads } ? ((try? await ChallengeService.squads()) ?? []) : []
            var found: [Item] = []
            for challenge in running {
                let rows = (try? await ChallengeService.standings(of: challenge.id)) ?? []
                found.append(.challenge(challenge, progress: ChallengeText.progress(in: challenge, standings: rows,
                                                                                     squads: squads, viewerId: viewer.userId)))
            }
            let shownEvents = events.filter { Self.isShown($0, now: now, calendar: calendar) }
                .sorted { $0.startsAt < $1.startsAt }
            items = shownEvents.map(Item.event) + found
        } catch {
            // A failed or cancelled load keeps the cards already shown, as the boat cards do.
        }
    }

    /// On now, starting later today, or still taking pieces rowed in it.
    private static func isShown(_ event: ErgEvent, now: Date, calendar: Calendar) -> Bool {
        let status = ChallengeRules.eventStatus(event, now: now)
        if status == .running || event.isOpenForPosting(at: now) { return true }
        return status == .upcoming && calendar.isDate(event.startsAt, inSameDayAs: now)
    }
}
