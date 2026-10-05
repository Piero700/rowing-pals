//
//  NotificationSettingsTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The app's half of notification settings: the row PostgREST returns and the row the app
/// writes. Quiet hours were removed (decision 36): their columns may still come back from the
/// database and are ignored, and the app never writes them. The server's half (who is sent
/// what) is checked by docs/testing/notifications.md.
struct NotificationSettingsTests {
    @Test func decodesTheRowPostgRESTReturnsIgnoringQuietHours() throws {
        let json = """
        {"user_id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","comments":true,"personal_bests":false,
         "club_activity":true,"quiet_hours_enabled":true,"quiet_start":"22:00:00",
         "quiet_end":"06:30:00","time_zone":"Europe/London"}
        """
        let settings = try JSONDecoder().decode(NotificationSettings.self, from: Data(json.utf8))
        #expect(settings.comments == true)
        #expect(settings.personalBests == false)
        #expect(settings.clubActivity == true)
    }

    @Test func writesOnlyTheThreeSwitches() throws {
        let settings = NotificationSettings.defaults(for: UUID())
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any]
        #expect(Set(object?.keys.map { $0 } ?? []) == ["user_id", "comments", "personal_bests", "club_activity"])
        #expect(object?["club_activity"] as? Bool == false)
    }

    @Test func defaultsMatchTheDesign() {
        let settings = NotificationSettings.defaults(for: UUID())
        #expect(settings.comments && settings.personalBests && !settings.clubActivity)
    }
}
