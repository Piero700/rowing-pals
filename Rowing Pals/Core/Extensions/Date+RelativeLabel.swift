//
//  Date+RelativeLabel.swift
//  Rowing Pals
//

import Foundation

extension Date {
    /// "3 min", "1h", "yesterday", "5d" — the terse relative-time style the
    /// feed cards use, rather than `RelativeDateTimeFormatter`'s longer
    /// "3 minutes ago" prose.
    var postedAgoLabel: String {
        let seconds = Int(Date().timeIntervalSince(self))
        if seconds < 60 { return "just now" }

        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }

        let days = hours / 24
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days)d" }

        return "\(days / 7)w"
    }
}
