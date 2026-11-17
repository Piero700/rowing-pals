//
//  AgeRules.swift
//  Rowing Pals
//

import Foundation

/// Who may use the app, and who counts as a junior (decision 107). Ages are worked out on the
/// person's own calendar: they turn 13 on their birthday where they are, not in UTC. The database
/// applies the same rules (docs/migrations/2026-11-17-minimum-age.sql).
nonisolated enum AgeRules {
    /// Nobody younger can have an account.
    static let minimumAge = 13
    /// Under this, a rower is a junior: private by default, no selfie by default, and their
    /// bodyweight hidden from coaches unless a parent or guardian agrees.
    static let adultAge = 18

    /// The message for anyone too young, wherever they're stopped.
    static let tooYoungMessage = "Rowing Pals is for people 13 and over."

    /// Whole years old on `day`.
    static func age(bornOn birthDate: Date, on day: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: calendar.startOfDay(for: birthDate),
                                to: calendar.startOfDay(for: day)).year ?? 0
    }

    static func isOldEnough(bornOn birthDate: Date, on day: Date = Date(), calendar: Calendar = .current) -> Bool {
        age(bornOn: birthDate, on: day, calendar: calendar) >= minimumAge
    }

    static func isJunior(bornOn birthDate: Date, on day: Date = Date(), calendar: Calendar = .current) -> Bool {
        age(bornOn: birthDate, on: day, calendar: calendar) < adultAge
    }

    /// The latest date of birth a picker offers: 13 today.
    static func latestBirthDate(on day: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .year, value: -minimumAge, to: calendar.startOfDay(for: day)) ?? day
    }

    /// The earliest date of birth a picker offers.
    static func earliestBirthDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast
    }
}
