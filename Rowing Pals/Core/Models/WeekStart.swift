//
//  WeekStart.swift
//  Rowing Pals
//

import Foundation

/// The day a club's week starts, set by its coaches in Settings (decision 69): calendars,
/// availability weeks and coaching's weekly totals follow it. Rankings and streaks stay Monday.
/// Mirrors `clubs.week_starts_on`.
nonisolated enum WeekStart: String, Codable, CaseIterable {
    case monday, sunday

    var label: String { self == .monday ? "Monday" : "Sunday" }

    /// For `Calendar.firstWeekday`: Sunday is 1, Monday 2.
    var firstWeekday: Int { self == .monday ? 2 : 1 }

    /// A calendar whose weeks start on this day.
    func calendar(_ base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}
