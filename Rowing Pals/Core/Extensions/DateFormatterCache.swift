//
//  DateFormatterCache.swift
//  Rowing Pals
//

import Foundation
import Synchronization

/// One `DateFormatter` per format, calendar and locale, made once and reused. Making a formatter
/// costs ~70 µs and using one ~1 µs (measured 2026-11-13), and the Calendar and challenge text
/// asked for a new one for every day cell and row they drew. Formatting with a shared formatter is
/// thread-safe; callers must never change one they're given.
nonisolated enum DateFormatterCache {
    private struct Key: Hashable {
        let format: String
        let calendar: Calendar
        let timeZone: TimeZone
        let locale: String
    }

    private static let formatters = Mutex<[Key: DateFormatter]>([:])

    static func formatter(_ format: String, calendar: Calendar, timeZone: TimeZone, locale: String) -> DateFormatter {
        let key = Key(format: format, calendar: calendar, timeZone: timeZone, locale: locale)
        return formatters.withLock { cache in
            if let known = cache[key] { return known }
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = timeZone
            formatter.locale = Locale(identifier: locale)
            formatter.dateFormat = format
            cache[key] = formatter
            return formatter
        }
    }
}
