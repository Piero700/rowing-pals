//
//  ClockTime.swift
//  Rowing Pals
//

import Foundation

/// A time of day with no date — the start or end of quiet hours. Stored in Postgres as a
/// `time` ("22:00:00"), shown on the 24-hour clock ("22:00"), as the v3 Settings row does.
nonisolated struct ClockTime: Hashable, Codable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// Reads "HH:mm" or "HH:mm:ss".
    init?(databaseValue: String) {
        let parts = databaseValue.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.init(hour: hour, minute: minute)
    }

    var databaseValue: String { String(format: "%02d:%02d:00", hour, minute) }

    /// "06:30".
    var label: String { String(format: "%02d:%02d", hour, minute) }

    /// Today at this time, for a `DatePicker`.
    func date(in calendar: Calendar = .current, on day: Date = Date()) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = ClockTime(databaseValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a time: \(raw)"))
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(databaseValue)
    }
}
