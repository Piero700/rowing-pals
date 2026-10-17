//
//  AnnouncementRules.swift
//  Rowing Pals
//

import Foundation

/// Announcements' arithmetic (decision 75), free of the network so it can be tested.
nonisolated enum AnnouncementRules {
    /// When an announcement posted at `now` comes off the Feed.
    static func expiry(from now: Date, duration: AnnouncementDuration, until custom: Date) -> Date {
        guard let hours = duration.hours else { return custom }
        return now.addingTimeInterval(Double(hours) * 60 * 60)
    }

    static func isLive(_ announcement: Announcement, now: Date) -> Bool {
        announcement.expiresAt > now
    }

    /// The ones on the Feed now, newest first.
    static func live(_ announcements: [Announcement], now: Date) -> [Announcement] {
        announcements.filter { isLive($0, now: now) }.sorted { $0.createdAt > $1.createdAt }
    }

    /// "today", "yesterday", "Wed", or "Fri 9 Oct" for longer ago.
    static func postedText(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "yesterday"
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days < 7 { return CalendarRules.weekdayShort(date, calendar: calendar).capitalized }
        return CalendarRules.dayLabel(date, calendar: calendar)
    }

    /// "Sat 18 Oct, 18:20".
    static func momentText(_ date: Date, calendar: Calendar) -> String {
        "\(CalendarRules.dayLabel(date, calendar: calendar)), \(CalendarRules.time(date, calendar: calendar))"
    }

    /// Whether this person can edit or delete the club's announcements: its coaches, the owner and
    /// co-owners (user, 2026-10-17).
    static func canManage(isCoach: Bool, role: ClubRole) -> Bool {
        isCoach || role >= .coOwner
    }
}
