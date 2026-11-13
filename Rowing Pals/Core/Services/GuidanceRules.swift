//
//  GuidanceRules.swift
//  Rowing Pals
//

import Foundation

/// When helper text shows (decision 98). Helper and guidance text — the notes under sections, the
/// explanations in footers, the hints on forms and empty states — shows until the person has opened
/// the app on **7 separate days** (their own local calendar day, never UTC), then hides by itself.
/// Settings → Help → **Helper text** turns it on or off by hand, and once they've chosen, their
/// choice wins over the count for good.
///
/// Pure rules, so they're unit-tested; the app root keeps the days and the choice on the device.
nonisolated enum GuidanceRules {
    /// The days of use after which helper text hides by itself.
    static let daysUntilHidden = 7

    /// The person's own choice in Settings, stored as text so `@AppStorage` can hold it.
    enum Choice: String {
        /// Never chosen: the 7-day count decides.
        case automatic = ""
        case on
        case off
    }

    /// The local calendar day `date` falls on, as "2026-11-05" — the key one day of use is counted
    /// under. Built from the calendar's own day, month and year, so 23:30 in London stays the day
    /// it is on the person's clock.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The days already counted (stored as "2026-11-01,2026-11-03"), read back as a list.
    static func days(from stored: String) -> [String] {
        stored.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    /// Counts `day` if it's a day not counted yet. Once 7 days are counted nothing more needs
    /// keeping, so the list never grows past that.
    static func recording(_ day: String, in stored: String) -> String {
        var counted = days(from: stored)
        guard !counted.contains(day), counted.count < daysUntilHidden else { return stored }
        counted.append(day)
        return counted.joined(separator: ",")
    }

    /// Whether helper text shows: the person's choice when they've made one, otherwise until the
    /// app has been opened on 7 separate days.
    static func showsGuidance(storedDays: String, choice: Choice) -> Bool {
        switch choice {
        case .on: true
        case .off: false
        case .automatic: days(from: storedDays).count < daysUntilHidden
        }
    }
}
