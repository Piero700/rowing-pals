//
//  AgeRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Decision 107: 13 or older to use the app, under 18 a junior — on the person's own calendar, so
/// they turn 13 on their birthday, not the day before or after.
struct AgeRulesTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth)) ?? .distantPast
    }

    @Test func thirteenOnTheBirthdayNotTheDayBefore() {
        let born = day(2013, 11, 17)
        #expect(!AgeRules.isOldEnough(bornOn: born, on: day(2026, 11, 16), calendar: calendar))
        #expect(AgeRules.isOldEnough(bornOn: born, on: day(2026, 11, 17), calendar: calendar))
    }

    @Test func juniorUntilTheEighteenthBirthday() {
        let born = day(2008, 11, 17)
        #expect(AgeRules.isJunior(bornOn: born, on: day(2026, 11, 16), calendar: calendar))
        #expect(!AgeRules.isJunior(bornOn: born, on: day(2026, 11, 17), calendar: calendar))
    }

    @Test func leapDayBirthdayIsThirteenByFirstOfMarch() {
        let born = day(2012, 2, 29)
        #expect(!AgeRules.isOldEnough(bornOn: born, on: day(2025, 2, 27), calendar: calendar))
        #expect(AgeRules.isOldEnough(bornOn: born, on: day(2025, 3, 1), calendar: calendar))
    }

    @Test func pickerStopsAtThirteenToday() {
        let latest = AgeRules.latestBirthDate(on: day(2026, 11, 17), calendar: calendar)
        #expect(latest == day(2013, 11, 17))
        #expect(AgeRules.isOldEnough(bornOn: latest, on: day(2026, 11, 17), calendar: calendar))
    }
}
