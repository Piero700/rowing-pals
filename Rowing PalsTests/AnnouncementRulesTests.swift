//
//  AnnouncementRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// How long announcements stay on the Feed and who can change them (decision 75).
struct AnnouncementRulesTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return calendar
    }()

    private static func date(_ d: Int, _ h: Int = 12, _ m: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: d, hour: h, minute: m)) ?? Date()
    }

    private static func announcement(posted: Date, expires: Date) -> Announcement {
        Announcement(id: UUID(), clubId: UUID(), heading: "Kit order closes Friday", message: nil,
                     expiresAt: expires, createdBy: nil, createdAt: posted)
    }

    @Test func anAnnouncementStaysTwentyFourHoursUnlessTheCoachSaysOtherwise() {
        let now = Self.date(17, 18, 20)
        #expect(AnnouncementDuration.allCases.first == .day)
        #expect(AnnouncementRules.expiry(from: now, duration: .day, until: now) == Self.date(18, 18, 20))
        #expect(AnnouncementRules.expiry(from: now, duration: .week, until: now) == Self.date(24, 18, 20))
        let custom = Self.date(20, 9)
        #expect(AnnouncementRules.expiry(from: now, duration: .custom, until: custom) == custom)
    }

    @Test func onlyAnnouncementsStillUpAreOnTheFeedNewestFirst() {
        let now = Self.date(17)
        let older = Self.announcement(posted: Self.date(15), expires: Self.date(18))
        let newer = Self.announcement(posted: Self.date(16), expires: Self.date(19))
        let ended = Self.announcement(posted: Self.date(10), expires: Self.date(12))
        #expect(AnnouncementRules.live([older, ended, newer], now: now) == [newer, older])
    }

    @Test func whenItWasPostedReadsNaturally() {
        let now = Self.date(17, 18)
        #expect(AnnouncementRules.postedText(Self.date(17, 9), now: now, calendar: Self.calendar) == "today")
        #expect(AnnouncementRules.postedText(Self.date(16, 9), now: now, calendar: Self.calendar) == "yesterday")
        #expect(AnnouncementRules.postedText(Self.date(14, 9), now: now, calendar: Self.calendar) == "Wed")
        #expect(AnnouncementRules.postedText(Self.date(2, 9), now: now, calendar: Self.calendar) == "Fri 2 Oct")
    }

    @Test func coachesAndOwnersLookAfterAnnouncements() {
        #expect(AnnouncementRules.canManage(isCoach: true, role: .member))
        #expect(AnnouncementRules.canManage(isCoach: false, role: .owner))
        #expect(AnnouncementRules.canManage(isCoach: false, role: .coOwner))
        #expect(!AnnouncementRules.canManage(isCoach: false, role: .admin))
        #expect(!AnnouncementRules.canManage(isCoach: false, role: .member))
    }
}
