//
//  WrappedRules.swift
//  Rowing Pals
//

import Foundation

/// Which seasons a rower can look back on (decision 92), free of the network so it can be tested:
/// the club's terms that have started, the latest first, named with their year; the one to open on;
/// the term that's just ended, for the Feed; and the rower's own dates.
nonisolated enum WrappedRules {
    /// How long after a term ends its Wrapped stays on the Feed.
    static let feedDays = 21

    /// The club's terms that have begun, latest first; "Michaelmas" becomes "Michaelmas 2026".
    static func periods(from terms: [ClubTerm], today: String) -> [WrappedPeriod] {
        terms.filter { $0.startsOn <= today }
            .sorted { $0.startsOn > $1.startsOn }
            .map { term in
                WrappedPeriod(termId: term.id, title: title(term), startsOn: term.startsOn, endsOn: term.endsOn)
            }
    }

    /// The term going on today, else the latest one; nil without terms.
    static func defaultPeriod(_ periods: [WrappedPeriod], today: String) -> WrappedPeriod? {
        periods.first { $0.startsOn <= today && today <= $0.endsOn } ?? periods.first
    }

    /// The term that ended in the last three weeks, the latest one: its Wrapped is on the Feed.
    static func readyTerm(_ terms: [ClubTerm], today: Date, calendar: Calendar) -> WrappedPeriod? {
        let todayString = ChallengeRules.day(today, calendar: calendar)
        guard let earliest = calendar.date(byAdding: .day, value: -feedDays, to: calendar.startOfDay(for: today)) else { return nil }
        let earliestString = ChallengeRules.day(earliest, calendar: calendar)
        return periods(from: terms, today: todayString)
            .filter { $0.endsOn < todayString && $0.endsOn >= earliestString }
            .max { $0.endsOn < $1.endsOn }
    }

    /// Still going: its numbers are "so far".
    static func isSoFar(_ period: WrappedPeriod, today: String) -> Bool {
        today <= period.endsOn
    }

    /// The rower's own days.
    static func custom(from start: Date, to end: Date, calendar: Calendar) -> WrappedPeriod {
        WrappedPeriod(termId: nil, title: "Your dates",
                      startsOn: ChallengeRules.day(min(start, end), calendar: calendar),
                      endsOn: ChallengeRules.day(max(start, end), calendar: calendar))
    }

    /// The name, with the year it started when the name hasn't one.
    static func title(_ term: ClubTerm) -> String {
        let name = term.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.contains(where: \.isNumber) else { return name }
        return "\(name) \(term.startsOn.prefix(4))"
    }
}
