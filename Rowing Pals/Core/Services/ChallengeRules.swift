//
//  ChallengeRules.swift
//  Rowing Pals
//

import Foundation

/// Challenges and erg events worked out from their rows (decision 91), free of the network so it
/// can be tested: whether one is on, how long is left, and each kind's standings — a personal
/// target's progress, a club total and its biggest contributors, squads on metres per rower.
nonisolated enum ChallengeRules {
    enum Status: Equatable {
        case upcoming, running, finished
    }

    /// A personal target: one rower's progress.
    struct TargetRow: Identifiable, Equatable {
        let standing: ChallengeStanding
        /// 0 … 1, capped.
        let progress: Double
        let isDone: Bool
        var id: UUID { standing.userId }
    }

    /// One squad in a squad-vs-squad challenge.
    struct SquadRow: Identifiable, Equatable {
        let id: UUID
        let name: String
        let members: [ChallengeStanding]
        let totalM: Int
        /// What the squads are ranked on, so a bigger squad doesn't win by size.
        let perRowerM: Int
    }

    /// "yyyy-MM-dd" for a moment, in the calendar's own time zone (the user's local day).
    static func day(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The date at the start of a "yyyy-MM-dd" day.
    static func date(_ day: String, calendar: Calendar) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func status(_ challenge: Challenge, today: String) -> Status {
        if today < challenge.startsOn { return .upcoming }
        if today > challenge.endsOn { return .finished }
        return .running
    }

    /// Days still to row, today included; 0 once it's over. Before it starts, its whole length.
    static func daysLeft(_ challenge: Challenge, now: Date, calendar: Calendar) -> Int {
        guard let start = date(challenge.startsOn, calendar: calendar), let end = date(challenge.endsOn, calendar: calendar) else { return 0 }
        let today = calendar.startOfDay(for: now)
        let from = max(today, start)
        guard from <= end else { return 0 }
        return (calendar.dateComponents([.day], from: from, to: end).day ?? 0) + 1
    }

    /// Everyone's progress towards a personal target, most metres first (ties by name).
    static func targetRows(_ standings: [ChallengeStanding], target: Int) -> [TargetRow] {
        sorted(standings).map { standing in
            TargetRow(standing: standing,
                      progress: target > 0 ? min(Double(standing.metres) / Double(target), 1) : 0,
                      isDone: target > 0 && standing.metres >= target)
        }
    }

    static func clubTotal(_ standings: [ChallengeStanding]) -> Int {
        standings.reduce(0) { $0 + $1.metres }
    }

    /// Who rowed the most, most first (ties by name); rowers with nothing yet left out.
    static func contributors(_ standings: [ChallengeStanding]) -> [ChallengeStanding] {
        sorted(standings.filter { $0.metres > 0 })
    }

    /// The squads in the challenge, best metres per rower first (ties: the bigger total). A rower
    /// in two of the squads counts for both; a squad with nobody in it has 0.
    static func squadRows(_ standings: [ChallengeStanding], squads: [Squad], ids: [UUID]) -> [SquadRow] {
        ids.compactMap { id -> SquadRow? in
            guard let squad = squads.first(where: { $0.id == id }) else { return nil }
            let members = sorted(standings.filter { $0.squadIds.contains(id) || squad.memberIds.contains($0.userId) })
            let total = members.reduce(0) { $0 + $1.metres }
            let perRower = members.isEmpty ? 0 : total / members.count
            return SquadRow(id: id, name: squad.name, members: members, totalM: total, perRowerM: perRower)
        }
        .sorted { $0.perRowerM != $1.perRowerM ? $0.perRowerM > $1.perRowerM : $0.totalM > $1.totalM }
    }

    /// Where a rower stands among others by metres: 1 is first.
    static func place(of userId: UUID, in standings: [ChallengeStanding]) -> Int? {
        sorted(standings).firstIndex { $0.userId == userId }.map { $0 + 1 }
    }

    // MARK: - Erg events

    static func eventStatus(_ event: ErgEvent, now: Date) -> Status {
        if now < event.startsAt { return .upcoming }
        if now > event.endsAt { return .finished }
        return .running
    }

    /// The board in order: fastest first for a distance, furthest first for a time (ties by name).
    static func eventBoard(_ results: [ErgEventResult], event: ErgEvent) -> [ErgEventResult] {
        results.sorted { a, b in
            if event.isRacedOnTime, a.timeMs != b.timeMs { return a.timeMs < b.timeMs }
            if !event.isRacedOnTime, a.distanceM != b.distanceM { return a.distanceM > b.distanceM }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    private static func sorted(_ standings: [ChallengeStanding]) -> [ChallengeStanding] {
        standings.sorted {
            $0.metres != $1.metres ? $0.metres > $1.metres
                : $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
