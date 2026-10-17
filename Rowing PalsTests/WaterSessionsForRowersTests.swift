//
//  WaterSessionsForRowersTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Decision 79: water sessions end; the Feed shows today's boats until they end, then tomorrow's;
/// the Calendar shows the rower's own, or the whole club's for those allowed to choose.
struct WaterSessionsForRowersTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return calendar
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? Date()
    }

    private func session(_ start: Date, hours: Double = 2) -> WaterSession {
        WaterSession(id: UUID(), clubId: UUID(), practiceId: nil, eventId: nil, title: "Water", startsAt: start,
                     endsAt: start.addingTimeInterval(hours * 3600), meetAt: nil, plan: nil, createdBy: nil)
    }

    @Test func theFeedShowsTodaysBoatsUntilTheyEnd() {
        let morning = session(at(19, 6))
        let evening = session(at(19, 17))
        let tomorrow = session(at(20, 6))
        let later = session(at(22, 6))
        let all = [morning, evening, tomorrow, later]
        // During the morning outing: both of today's.
        #expect(BoatRules.feedBoats(all, session: { $0 }, now: at(19, 7), calendar: calendar) == [morning, evening])
        // The morning one has ended: just the evening.
        #expect(BoatRules.feedBoats(all, session: { $0 }, now: at(19, 9), calendar: calendar) == [evening])
        // Today's are all over: tomorrow's appear.
        #expect(BoatRules.feedBoats(all, session: { $0 }, now: at(19, 20), calendar: calendar) == [tomorrow])
        // Nothing today or tomorrow: nothing further ahead on the Feed.
        #expect(BoatRules.feedBoats([later], session: { $0 }, now: at(19, 20), calendar: calendar).isEmpty)
    }

    @Test func onlyCoachesAndClubAdminsChooseTheWholeClub() {
        #expect(WaterCalendarScope.canChoose(isCoach: true, clubRole: .member))
        #expect(WaterCalendarScope.canChoose(isCoach: false, clubRole: .admin))
        #expect(WaterCalendarScope.canChoose(isCoach: false, clubRole: .owner))
        #expect(!WaterCalendarScope.canChoose(isCoach: false, clubRole: .member))
        #expect(WaterCalendarScope.resolved(.club, isCoach: false, clubRole: .member) == .mine)
        #expect(WaterCalendarScope.resolved(.club, isCoach: false, clubRole: .coOwner) == .club)
        #expect(WaterCalendarScope.allCases.map(\.label) == ["Mine", "Whole club"])
    }

    @Test func aSessionWithoutAnEndEndsTwoHoursLater() throws {
        let json = """
        {"id":"\(UUID().uuidString)","club_id":"\(UUID().uuidString)","title":"Water","starts_at":"2026-10-19T05:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(WaterSession.self, from: Data(json.utf8))
        #expect(session.endsAt.timeIntervalSince(session.startsAt) == 2 * 3600)
    }
}
