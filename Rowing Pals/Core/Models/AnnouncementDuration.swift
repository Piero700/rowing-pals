//
//  AnnouncementDuration.swift
//  Rowing Pals
//

/// How long an announcement stays on rowers' Feeds (decision 75): 24 hours unless the coach
/// chooses longer, or a day and time of their own.
nonisolated enum AnnouncementDuration: Int, CaseIterable {
    case day, threeDays, week, custom

    var label: String {
        switch self {
        case .day: "24 hours"
        case .threeDays: "3 days"
        case .week: "1 week"
        case .custom: "Until…"
        }
    }

    /// In hours; nil for a day and time the coach picks.
    var hours: Int? {
        switch self {
        case .day: 24
        case .threeDays: 72
        case .week: 168
        case .custom: nil
        }
    }
}
