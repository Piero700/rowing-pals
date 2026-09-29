//
//  NotificationSettings.swift
//  Rowing Pals
//

import Foundation

/// Mirrors `notification_settings` (docs/migrations/2026-09-26-notifications.sql): which
/// alerts a rower wants and their quiet hours. A rower with no row gets `defaults(for:)`,
/// the same values as the table's column defaults.
nonisolated struct NotificationSettings: Codable, Equatable {
    let userId: UUID
    /// Someone comments on your post, or on a post you've commented on.
    var comments: Bool
    /// You, or someone you follow, sets a new personal best.
    var personalBests: Bool
    /// A clubmate posts.
    var clubActivity: Bool
    var quietHoursEnabled: Bool
    var quietStart: ClockTime
    var quietEnd: ClockTime
    /// The phone's zone, so quiet hours follow the rower's own clock.
    var timeZone: String

    static func defaults(for userId: UUID, timeZone: String = TimeZone.current.identifier) -> NotificationSettings {
        NotificationSettings(
            userId: userId,
            comments: true,
            personalBests: true,
            clubActivity: false,
            quietHoursEnabled: true,
            quietStart: ClockTime(hour: 22, minute: 0),
            quietEnd: ClockTime(hour: 6, minute: 30),
            timeZone: timeZone
        )
    }

    /// The Quiet hours row's subtitle: "22:00–06:30", or "Off".
    var quietHoursLabel: String {
        quietHoursEnabled ? "\(quietStart.label)–\(quietEnd.label)" : "Off"
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case comments
        case personalBests = "personal_bests"
        case clubActivity = "club_activity"
        case quietHoursEnabled = "quiet_hours_enabled"
        case quietStart = "quiet_start"
        case quietEnd = "quiet_end"
        case timeZone = "time_zone"
    }
}
