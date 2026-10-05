//
//  CoachingRules.swift
//  Rowing Pals
//

import Foundation
import PaceEngine

/// The arithmetic behind Coaching (decisions 34, 39, 43), kept free of the network so it can be
/// tested: the pro-rata weekly target, the flags, the list's sort and squad filter, and the
/// numbers on one rower's page. Weeks start on Monday and days are the rower's local calendar
/// days, as everywhere else in the app.
nonisolated enum CoachingRules {
    /// Days of history read for the list: the Pace Engine's 30-day window plus enough to tell a
    /// lapsed rower from a new one (the same as `PredictionService`).
    static let historyDays = 60
    /// No session for this many days or more raises a flag (decision 39).
    static let noSessionDays = 10

    /// `calendar` with weeks starting on Monday.
    static func mondayCalendar(_ base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2
        return calendar
    }

    /// The Monday that starts `date`'s week.
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let monday = mondayCalendar(calendar)
        return monday.dateInterval(of: .weekOfYear, for: date)?.start ?? monday.startOfDay(for: date)
    }

    // MARK: - Weekly target

    /// The share of the weekly target due by now, pro-rata (decision 43): one seventh for each
    /// day of the week that has **ended**. Nothing is due on Monday, six sevenths on Sunday; today
    /// is still to play for, so nobody is behind for not having rowed yet today.
    static func proRataTargetM(weeklyTargetM: Int, asOf: Date, calendar: Calendar) -> Int {
        guard weeklyTargetM > 0 else { return 0 }
        let start = weekStart(of: asOf, calendar: calendar)
        let today = calendar.startOfDay(for: asOf)
        let completedDays = min(7, max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0))
        return weeklyTargetM * completedDays / 7
    }

    /// Metres short of the pro-rata target; 0 when on track.
    static func shortfallM(weekMetres: Int, weeklyTargetM: Int, asOf: Date, calendar: Calendar) -> Int {
        max(0, proRataTargetM(weeklyTargetM: weeklyTargetM, asOf: asOf, calendar: calendar) - weekMetres)
    }

    // MARK: - Flags

    /// Whole calendar days from `day` to `asOf`.
    static func daysBetween(_ day: Date, and asOf: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: day), to: calendar.startOfDay(for: asOf)).day ?? 0
    }

    /// What a coach should look at (decision 39), in the order they show.
    /// - Parameters:
    ///   - daysSinceSession: nil when there's no session in the last `historyDays` days.
    ///   - accountAgeDays: how long the account has existed, so a rower who joined last week
    ///     isn't flagged for not having rowed for 60 days.
    static func flags(
        prediction: Prediction?,
        daysSinceSession: Int?,
        accountAgeDays: Int,
        effortChangePercent: Int?
    ) -> [CoachFlag] {
        var flags: [CoachFlag] = []
        if let days = daysSinceSession {
            if days >= noSessionDays { flags.append(.noRecentSession(days: days)) }
        } else if accountAgeDays >= noSessionDays {
            flags.append(.noRecentSession(days: accountAgeDays <= historyDays ? accountAgeDays : nil))
        }
        if let prediction {
            if prediction.flags.contains("elevated_recent_effort") {
                flags.append(.elevatedEffort(percentAbove: effortChangePercent))
            }
            if prediction.flags.contains("tier_disagreement") {
                let zones = likelyMistag(twoKByTier: prediction.diagnostics.twoKEquivalentByTier)
                flags.append(.likelyMistagged(
                    logged: zones?.logged,
                    likely: zones?.likely,
                    spreadSeconds: prediction.diagnostics.spreadSeconds
                ))
            }
        }
        return flags
    }

    /// Which zone was probably logged wrongly, and what it was really rowed at, from the engine's
    /// 2k equivalent per zone. The zone furthest from the others' median is the odd one out; its
    /// sessions' true zone is the one whose offset explains the gap. A session logged as zone
    /// `Y` but rowed at zone `X` reads as a 2k equivalent off by `offset(X) − offset(Y)`.
    /// Needs three zones, so there's a majority to disagree with; nil otherwise.
    static func likelyMistag(twoKByTier: [String: Double]) -> (logged: Tier.Name, likely: Tier.Name)? {
        let entries = twoKByTier.compactMap { key, value in Tier.Name(rawValue: key).map { ($0, value) } }
        guard entries.count >= 3 else { return nil }
        var oddOne: (name: Tier.Name, delta: Double)?
        for (name, value) in entries {
            let others = entries.filter { $0.0 != name }.map(\.1).sorted()
            let middle = others.count / 2
            let median = others.count.isMultiple(of: 2) ? (others[middle - 1] + others[middle]) / 2 : others[middle]
            let delta = value - median
            if abs(delta) > abs(oddOne?.delta ?? 0) { oddOne = (name, delta) }
        }
        guard let oddOne else { return nil }
        let impliedOffset = Tier.named(oddOne.name).offset + oddOne.delta
        guard let nearest = Tier.all.min(by: { abs($0.offset - impliedOffset) < abs($1.offset - impliedOffset) }),
              nearest.name != oddOne.name else { return nil }
        return (oddOne.name, nearest.name)
    }

    // MARK: - Effort

    /// One rated session: its day and effort (1–10).
    struct Rating: Equatable {
        let day: Date
        let rpe: Double
    }

    /// The last 7 days' average effort against the last 4 weeks', as a whole percentage
    /// (24 means 24% higher); nil without a rating in the last 7 days and two in the 4 weeks.
    static func effortChangePercent(_ ratings: [Rating], asOf: Date, calendar: Calendar) -> Int? {
        let recent = ratings.filter { daysBetween($0.day, and: asOf, calendar: calendar) < 7 }
        let month = ratings.filter { daysBetween($0.day, and: asOf, calendar: calendar) < 28 }
        guard !recent.isEmpty, month.count >= 2 else { return nil }
        let recentAverage = recent.map(\.rpe).reduce(0, +) / Double(recent.count)
        let monthAverage = month.map(\.rpe).reduce(0, +) / Double(month.count)
        guard monthAverage > 0 else { return nil }
        return Int(((recentAverage / monthAverage - 1) * 100).rounded())
    }

    /// Average effort per session for each of the last `weeks` weeks, oldest first (nil for a
    /// week with no ratings).
    static func weeklyEffort(_ ratings: [Rating], weeks: Int = 8, asOf: Date, calendar: Calendar) -> [Double?] {
        let starts = weekStarts(weeks: weeks, asOf: asOf, calendar: calendar)
        return starts.map { start in
            let week = ratings.filter { weekStart(of: $0.day, calendar: calendar) == start }
            guard !week.isEmpty else { return nil }
            return week.map(\.rpe).reduce(0, +) / Double(week.count)
        }
    }

    /// Average effort per session over the last `days` days.
    static func averageEffort(_ ratings: [Rating], days: Int, asOf: Date, calendar: Calendar) -> Double? {
        let window = ratings.filter { daysBetween($0.day, and: asOf, calendar: calendar) < days }
        guard !window.isEmpty else { return nil }
        return window.map(\.rpe).reduce(0, +) / Double(window.count)
    }

    // MARK: - Volume and zones

    /// The Mondays of the last `weeks` weeks, oldest first, ending with this week's.
    static func weekStarts(weeks: Int, asOf: Date, calendar: Calendar) -> [Date] {
        let current = weekStart(of: asOf, calendar: calendar)
        return (0..<weeks).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: current) }
    }

    /// Metres per week for the last `weeks` weeks, oldest first.
    static func weeklyMetres(_ days: [(day: Date, metres: Int)], weeks: Int = 8, asOf: Date, calendar: Calendar) -> [Int] {
        let starts = weekStarts(weeks: weeks, asOf: asOf, calendar: calendar)
        var totals = Array(repeating: 0, count: starts.count)
        for entry in days {
            let start = weekStart(of: entry.day, calendar: calendar)
            if let index = starts.firstIndex(of: start) { totals[index] += entry.metres }
        }
        return totals
    }

    /// Each zone's share of the metres, easiest first (UT2 … AN), as fractions adding to 1;
    /// empty with no zoned metres.
    static func zoneMix(_ metresByZone: [Tier.Name: Int]) -> [(zone: Tier.Name, share: Double)] {
        let total = metresByZone.values.reduce(0, +)
        guard total > 0 else { return [] }
        return Tier.all.reversed().map { tier in
            (tier.name, Double(metresByZone[tier.name] ?? 0) / Double(total))
        }
    }

    // MARK: - Athlete

    /// Whole years old on `asOf`.
    static func age(birthDate: Date, asOf: Date, calendar: Calendar) -> Int? {
        calendar.dateComponents([.year], from: birthDate, to: asOf).year
    }

    /// Concept2's power for an average split: 2.80 / (seconds per metre)³.
    static func watts(splitMs: Int) -> Double? {
        guard splitMs > 0 else { return nil }
        let secondsPerMetre = Double(splitMs) / 1000 / 500
        return 2.80 / (secondsPerMetre * secondsPerMetre * secondsPerMetre)
    }

    // MARK: - Squads

    /// "12 rowers · Joe Fenwick, Marcus Reilly, Nina Bergström and 9 more" (CoachSquads): up to
    /// three names, alphabetical, then how many more.
    static func squadSummary(memberNames: [String]) -> String {
        let count = memberNames.count
        let head = "\(count) rower\(count == 1 ? "" : "s")"
        guard count > 0 else { return head }
        let sorted = memberNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let shown = sorted.prefix(count > 3 ? 3 : count)
        var names = shown.joined(separator: ", ")
        if count > 3 {
            names += " and \(count - 3) more"
        } else if count > 1, let last = shown.last {
            names = shown.dropLast().joined(separator: ", ") + " and " + last
        }
        return "\(head) · \(names)"
    }

    // MARK: - The list

    /// Only the rowers in `squad`; everyone when nil.
    static func filtered(_ rowers: [CoachRower], squad: UUID?) -> [CoachRower] {
        guard let squad else { return rowers }
        return rowers.filter { $0.squadIds.contains(squad) }
    }

    static func sorted(_ rowers: [CoachRower], by sort: RosterSort) -> [CoachRower] {
        rowers.sorted { a, b in
            switch sort {
            case .behindTarget:
                if a.shortfallM != b.shortfallM { return a.shortfallM > b.shortfallM }
            case .notLogged:
                // Nothing in the window reads as the longest gap of all.
                let aDays = a.daysSinceSession ?? Int.max
                let bDays = b.daysSinceSession ?? Int.max
                if aDays != bDays { return aDays > bDays }
            case .name:
                break
            }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }
}
