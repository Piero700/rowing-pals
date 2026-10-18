//
//  ChallengeText.swift
//  Rowing Pals
//

import Foundation

/// How challenges and erg events read (decision 91), in Rankings and on the Feed: their days, what's
/// left, your progress, an event's window and a result. Metres follow the Rankings unit setting
/// (metres or km), as leaderboard totals do.
enum ChallengeText {
    private static let calendar = Calendar.current

    /// "42,000m" or "42.0km".
    static func metres(_ value: Int) -> String {
        value.formattedDistance(unit: DistanceUnit.current)
    }

    /// "1 – 30 Nov", "28 Oct – 3 Nov", "Sat 1 Nov" for a single day.
    static func days(_ challenge: Challenge) -> String {
        guard let start = ChallengeRules.date(challenge.startsOn, calendar: calendar),
              let end = ChallengeRules.date(challenge.endsOn, calendar: calendar) else { return "" }
        if challenge.startsOn == challenge.endsOn { return format(start, "EEE d MMM") }
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        return "\(format(start, sameMonth ? "d" : "d MMM")) – \(format(end, "d MMM"))"
    }

    /// "3 days left", "Last day", "Starts Sat 1 Nov", "Finished 30 Nov".
    static func when(_ challenge: Challenge, now: Date = Date()) -> String {
        let today = ChallengeRules.day(now, calendar: calendar)
        switch ChallengeRules.status(challenge, today: today) {
        case .upcoming:
            return "Starts \(ChallengeRules.date(challenge.startsOn, calendar: calendar).map { format($0, "EEE d MMM") } ?? challenge.startsOn)"
        case .finished:
            return "Finished \(ChallengeRules.date(challenge.endsOn, calendar: calendar).map { format($0, "d MMM") } ?? challenge.endsOn)"
        case .running:
            let left = ChallengeRules.daysLeft(challenge, now: now, calendar: calendar)
            return left <= 1 ? "Last day" : "\(left) days left"
        }
    }

    /// "Sat 1 Nov, 09:00–12:00", or "Sat 1 Nov 09:00 – Sun 2 Nov 18:00" over more than a day.
    static func window(_ event: ErgEvent) -> String {
        if calendar.isDate(event.startsAt, inSameDayAs: event.endsAt) {
            return "\(format(event.startsAt, "EEE d MMM")), \(format(event.startsAt, "HH:mm"))–\(format(event.endsAt, "HH:mm"))"
        }
        return "\(format(event.startsAt, "EEE d MMM HH:mm")) – \(format(event.endsAt, "EEE d MMM HH:mm"))"
    }

    /// "On until 12:00", "Starts Sat 09:00", "Finished Sat 1 Nov"; posting still open says so.
    static func when(_ event: ErgEvent, now: Date = Date()) -> String {
        switch ChallengeRules.eventStatus(event, now: now) {
        case .upcoming:
            return "Starts \(format(event.startsAt, calendar.isDate(event.startsAt, inSameDayAs: now) ? "HH:mm" : "EEE d MMM HH:mm"))"
        case .running:
            return "On until \(format(event.endsAt, calendar.isDate(event.endsAt, inSameDayAs: now) ? "HH:mm" : "EEE HH:mm"))"
        case .finished:
            return event.isOpenForPosting(at: now)
                ? "Finished · post a piece rowed in it until \(format(event.endsAt.addingTimeInterval(ErgEvent.postingGrace), "HH:mm"))"
                : "Finished \(format(event.endsAt, "EEE d MMM"))"
        }
    }

    /// A board's value: the time for a distance, the distance for a time.
    static func result(_ result: ErgEventResult, event: ErgEvent) -> String {
        event.isRacedOnTime ? result.timeMs.formattedDurationMs : result.distanceM.formattedMetres
    }

    /// "Senior men", "Novice women", "Rower".
    static func group(_ result: ErgEventResult) -> String {
        let level = result.category.map { $0 == .senior ? "Senior" : "Novice" }
        let gender = result.gender.map { $0 == .male ? "men" : "women" }
        switch (level, gender) {
        case let (level?, gender?): return "\(level) \(gender)"
        case let (level?, nil): return level
        default: return "Rower"
        }
    }

    /// What a running challenge says about the viewer, with the bar's fill: "You · 42.0km of 100.0km",
    /// "Club · 1,240.0km of 2,000.0km", "Seniors lead · Novices 2nd".
    static func progress(in challenge: Challenge, standings rows: [ChallengeStanding], squads: [Squad],
                         viewerId: UUID?) -> (text: String, fraction: Double, isDone: Bool)? {
        switch challenge.kind {
        case .target:
            guard let target = challenge.targetM else { return nil }
            let mine = rows.first { $0.userId == viewerId }?.metres ?? 0
            let done = mine >= target
            return ("\(done ? "Done · " : "You · ")\(metres(mine)) of \(metres(target))", Double(mine) / Double(max(target, 1)), done)
        case .clubTotal:
            guard let target = challenge.targetM else { return nil }
            let total = ChallengeRules.clubTotal(rows)
            return ("Club · \(metres(total)) of \(metres(target))", Double(total) / Double(max(target, 1)), total >= target)
        case .squads:
            let ranked = ChallengeRules.squadRows(rows, squads: squads, ids: challenge.squadIds)
            guard let leader = ranked.first else { return nil }
            let mine = ranked.firstIndex { squad in squad.members.contains { $0.userId == viewerId } }
            let text = mine.map { index in
                index == 0 ? "Your squad leads: \(leader.name)" : "\(leader.name) lead · \(ranked[index].name) \(ordinal(index + 1))"
            } ?? "\(leader.name) lead"
            let fraction = mine.map { Double(ranked[$0].perRowerM) / Double(max(leader.perRowerM, 1)) } ?? 1
            return (text, fraction, false)
        }
    }

    /// "1st", "2nd", "11th".
    static func ordinal(_ value: Int) -> String {
        value.formattedOrdinal
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.calendar = calendar
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
