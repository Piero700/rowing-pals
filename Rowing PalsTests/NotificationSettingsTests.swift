//
//  NotificationSettingsTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The app's half of notification settings: reading and writing Postgres `time` values, the
/// row PostgREST returns, and the Quiet hours row's subtitle. The server's half (who is sent
/// what, and quiet hours on the rower's clock) is checked by docs/testing/notifications.md.
struct NotificationSettingsTests {
    @Test func clockTimeReadsPostgresTimes() {
        #expect(ClockTime(databaseValue: "22:00:00") == ClockTime(hour: 22, minute: 0))
        #expect(ClockTime(databaseValue: "06:30") == ClockTime(hour: 6, minute: 30))
        #expect(ClockTime(databaseValue: "24:00:00") == nil)
        #expect(ClockTime(databaseValue: "7") == nil)
    }

    @Test func clockTimeWritesAndLabels() {
        let time = ClockTime(hour: 6, minute: 30)
        #expect(time.databaseValue == "06:30:00")
        #expect(time.label == "06:30")
    }

    @Test func clockTimeSurvivesADatePickerRoundTrip() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        let time = ClockTime(hour: 22, minute: 15)
        #expect(ClockTime(date: time.date(in: calendar), calendar: calendar) == time)
    }

    @Test func decodesTheRowPostgRESTReturns() throws {
        let json = """
        {"user_id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","comments":true,"personal_bests":false,
         "club_activity":true,"quiet_hours_enabled":true,"quiet_start":"22:00:00",
         "quiet_end":"06:30:00","time_zone":"Europe/London"}
        """
        let settings = try JSONDecoder().decode(NotificationSettings.self, from: Data(json.utf8))
        #expect(settings.personalBests == false)
        #expect(settings.clubActivity == true)
        #expect(settings.quietStart == ClockTime(hour: 22, minute: 0))
        #expect(settings.quietHoursLabel == "22:00–06:30")
    }

    @Test func encodesTimesAsPostgresTimes() throws {
        let settings = NotificationSettings.defaults(for: UUID(), timeZone: "Europe/London")
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any]
        #expect(object?["quiet_start"] as? String == "22:00:00")
        #expect(object?["quiet_end"] as? String == "06:30:00")
        #expect(object?["club_activity"] as? Bool == false)
    }

    @Test func defaultsMatchTheDesign() {
        let settings = NotificationSettings.defaults(for: UUID())
        #expect(settings.comments && settings.personalBests && !settings.clubActivity)
        var off = settings
        off.quietHoursEnabled = false
        #expect(off.quietHoursLabel == "Off")
    }
}
