//
//  CoachingRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import PaceEngine
import Testing
@testable import Rowing_Pals

/// Coaching Phase 1's rules (decisions 34, 39, 43): the pro-rata weekly target, the three flags,
/// the likely mis-tag, effort and volume arithmetic, the list's squad filter and sort, squads'
/// summaries, coach-only accounts off the leaderboards, and who may make a coach.
@MainActor
struct CoachingRulesTests {
    /// Gregorian, UTC, so the dates below never shift with the test machine's time zone.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// 2026-10-05 is a Monday.
    private static func day(_ dayOfMonth: Int, month: Int = 10, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: dayOfMonth, hour: hour)) ?? Date()
    }

    // MARK: - Pro-rata target

    @Test func nothingIsDueOnMonday() {
        #expect(CoachingRules.proRataTargetM(weeklyTargetM: 70_000, asOf: Self.day(5), calendar: Self.calendar) == 0)
    }

    @Test func eachEndedDayAddsASeventh() {
        // Wednesday: Monday and Tuesday have ended.
        #expect(CoachingRules.proRataTargetM(weeklyTargetM: 70_000, asOf: Self.day(7), calendar: Self.calendar) == 20_000)
        // Sunday: six days have ended.
        #expect(CoachingRules.proRataTargetM(weeklyTargetM: 70_000, asOf: Self.day(11, hour: 23), calendar: Self.calendar) == 60_000)
    }

    @Test func noTargetIsNeverBehind() {
        #expect(CoachingRules.shortfallM(weekMetres: 0, weeklyTargetM: 0, asOf: Self.day(11), calendar: Self.calendar) == 0)
    }

    @Test func behindOnlyWhenUnderTheProRataShare() {
        let wednesday = Self.day(7)
        #expect(CoachingRules.shortfallM(weekMetres: 12_000, weeklyTargetM: 70_000, asOf: wednesday, calendar: Self.calendar) == 8_000)
        #expect(CoachingRules.shortfallM(weekMetres: 20_000, weeklyTargetM: 70_000, asOf: wednesday, calendar: Self.calendar) == 0)
        #expect(CoachingRules.shortfallM(weekMetres: 35_000, weeklyTargetM: 70_000, asOf: wednesday, calendar: Self.calendar) == 0)
    }

    // MARK: - Flags

    @Test func tenDaysWithoutASessionIsFlagged() {
        let flags = CoachingRules.flags(prediction: nil, daysSinceSession: 10, accountAgeDays: 200, effortChangePercent: nil)
        #expect(flags == [.noRecentSession(days: 10)])
        #expect(flags.first?.chipText == "No session in 10 days")
        #expect(CoachingRules.flags(prediction: nil, daysSinceSession: 9, accountAgeDays: 200, effortChangePercent: nil).isEmpty)
    }

    @Test func aNewAccountIsNotFlaggedForItsFirstDays() {
        #expect(CoachingRules.flags(prediction: nil, daysSinceSession: nil, accountAgeDays: 5, effortChangePercent: nil).isEmpty)
        #expect(CoachingRules.flags(prediction: nil, daysSinceSession: nil, accountAgeDays: 14, effortChangePercent: nil)
            == [.noRecentSession(days: 14)])
        // Older than the window read: the gap is at least the window.
        let lapsed = CoachingRules.flags(prediction: nil, daysSinceSession: nil, accountAgeDays: 400, effortChangePercent: nil)
        #expect(lapsed == [.noRecentSession(days: nil)])
        #expect(lapsed.first?.chipText == "No session in 60+ days")
    }

    @Test func engineFlagsBecomeCoachFlags() throws {
        let prediction = try Self.prediction(
            flags: ["elevated_recent_effort", "tier_disagreement", "load_estimate_damped"],
            twoKByTier: ["AN": 100, "AT": 100.4, "UT1": 99.8, "UT2": 95],
            spread: 5.4
        )
        let flags = CoachingRules.flags(prediction: prediction, daysSinceSession: 2, accountAgeDays: 100, effortChangePercent: 24)
        #expect(flags == [
            .elevatedEffort(percentAbove: 24),
            .likelyMistagged(logged: .ut2, likely: .ut1, spreadSeconds: 5.4)
        ])
        #expect(flags[0].isWarning)
        #expect(!flags[1].isWarning)
        #expect(flags[1].chipText == "Likely mis-tagged: UT1 logged as UT2")
        #expect(flags[0].detailText == "Effort over the last 7 days is 24% above their 4-week average.")
    }

    // MARK: - Likely mis-tag

    @Test func theOddZoneOutIsNamedWithTheZoneItWasRowedAt() {
        // UT2 sessions read 5 s/500m fast against the others: rowed at UT1 (offset 17, not 22).
        let zones = CoachingRules.likelyMistag(twoKByTier: ["AN": 100, "AT": 100.4, "UT1": 99.8, "UT2": 95])
        #expect(zones?.logged == .ut2)
        #expect(zones?.likely == .ut1)
        // AT sessions 4 s slow: rowed easier, at UT1 pace (13 + 4 = 17).
        let easier = CoachingRules.likelyMistag(twoKByTier: ["AN": 100, "AT": 104, "UT1": 100.2, "UT2": 99.9])
        #expect(easier?.logged == .at)
        #expect(easier?.likely == .ut1)
    }

    @Test func twoZonesOrASmallGapNameNoZone() {
        #expect(CoachingRules.likelyMistag(twoKByTier: ["AN": 100, "UT2": 95]) == nil)
        #expect(CoachingRules.likelyMistag(twoKByTier: ["AN": 100, "AT": 100.5, "UT2": 99]) == nil)
    }

    // MARK: - Effort and volume

    @Test func effortChangeComparesTheWeekWithTheMonth() {
        let asOf = Self.day(20)
        let ratings = [
            CoachingRules.Rating(day: Self.day(19), rpe: 8),
            CoachingRules.Rating(day: Self.day(16), rpe: 8),
            CoachingRules.Rating(day: Self.day(8), rpe: 5),
            CoachingRules.Rating(day: Self.day(1), rpe: 5),
            CoachingRules.Rating(day: Self.day(1, month: 9), rpe: 10)  // outside the 4 weeks
        ]
        // Week 8.0 against month 6.5: 23% higher.
        #expect(CoachingRules.effortChangePercent(ratings, asOf: asOf, calendar: Self.calendar) == 23)
        #expect(CoachingRules.effortChangePercent([], asOf: asOf, calendar: Self.calendar) == nil)
    }

    @Test func weeklyMetresBucketByMondayWeeks() {
        let asOf = Self.day(7)  // Wednesday 7 Oct
        let days: [(day: Date, metres: Int)] = [
            (Self.day(5), 10_000), (Self.day(7), 6_000),     // this week
            (Self.day(4), 12_000), (Self.day(28, month: 9), 3_000),  // last week (Mon 28 Sep – Sun 4 Oct)
            (Self.day(1, month: 8), 99_000)                  // older than 8 weeks
        ]
        let weeks = CoachingRules.weeklyMetres(days, asOf: asOf, calendar: Self.calendar)
        #expect(weeks.count == 8)
        #expect(weeks.last == 16_000)
        #expect(weeks[6] == 15_000)
        #expect(weeks.dropLast(2).allSatisfy { $0 == 0 })
    }

    @Test func zoneMixAddsToOneEasiestFirst() {
        let mix = CoachingRules.zoneMix([.ut2: 6_000, .ut1: 3_000, .an: 1_000])
        #expect(mix.map(\.zone) == [.ut2, .ut1, .at, .tr, .an])
        #expect(abs(mix.map(\.share).reduce(0, +) - 1) < 0.000_001)
        #expect(mix.first?.share == 0.6)
        #expect(CoachingRules.zoneMix([:]).isEmpty)
    }

    @Test func wattsFollowConcept2() throws {
        // 2:00.0 /500m is 202.5 W.
        let watts = try #require(CoachingRules.watts(splitMs: 120_000))
        #expect(abs(watts - 202.546) < 0.01)
        #expect(CoachingRules.watts(splitMs: 0) == nil)
    }

    @Test func ageCountsWholeYears() {
        let born = Self.calendar.date(from: DateComponents(year: 2005, month: 10, day: 6)) ?? Date()
        #expect(CoachingRules.age(birthDate: born, asOf: Self.day(5), calendar: Self.calendar) == 20)
        #expect(CoachingRules.age(birthDate: born, asOf: Self.day(6), calendar: Self.calendar) == 21)
    }

    // MARK: - Prediction wording

    @Test func predictionShowsTheTimeToTheSecondAndItsRange() throws {
        let prediction = try Self.prediction(flags: [], twoKByTier: [:], spread: 0, totalSeconds: 439.6, rangeSeconds: 8.7)
        #expect(CoachRowerText.prediction(prediction) == "7:20 ±9s")
        #expect(CoachRowerText.predictedTime(prediction) == "7:20")
        #expect(CoachRowerText.range(prediction) == "±9s")
        let tight = try Self.prediction(flags: [], twoKByTier: [:], spread: 0, totalSeconds: 370.0, rangeSeconds: 0.3)
        #expect(CoachRowerText.range(tight) == "±1s")
        #expect(CoachRowerText.prediction(nil) == "—")
    }

    // MARK: - The list

    @Test func squadFilterKeepsOnlyItsRowers() {
        let novices = UUID()
        let list = [Self.rower("Ann", squads: [novices]), Self.rower("Ben"), Self.rower("Cat", squads: [novices, UUID()])]
        #expect(CoachingRules.filtered(list, squad: novices).map(\.displayName) == ["Ann", "Cat"])
        #expect(CoachingRules.filtered(list, squad: nil).count == 3)
    }

    @Test func sortsPutTheRowersToLookAtFirst() {
        let list = [
            Self.rower("Cat", shortfall: 0, daysSince: 1),
            Self.rower("ann", shortfall: 8_000, daysSince: 12),
            Self.rower("Ben", shortfall: 20_000, daysSince: nil),
            Self.rower("Dan", shortfall: 8_000, daysSince: 3)
        ]
        #expect(CoachingRules.sorted(list, by: .behindTarget).map(\.displayName) == ["Ben", "ann", "Dan", "Cat"])
        #expect(CoachingRules.sorted(list, by: .notLogged).map(\.displayName) == ["Ben", "ann", "Dan", "Cat"])
        #expect(CoachingRules.sorted(list, by: .name).map(\.displayName) == ["ann", "Ben", "Cat", "Dan"])
    }

    @Test func squadSummaryNamesUpToThree() {
        #expect(CoachingRules.squadSummary(memberNames: []) == "0 rowers")
        #expect(CoachingRules.squadSummary(memberNames: ["Alice Whitfield"]) == "1 rower · Alice Whitfield")
        #expect(CoachingRules.squadSummary(memberNames: ["Dan Okafor", "Tom Ashworth"]) == "2 rowers · Dan Okafor and Tom Ashworth")
        #expect(CoachingRules.squadSummary(memberNames: ["Tom", "Dan", "Ann", "Ben", "Cat"]) == "5 rowers · Ann, Ben, Cat and 2 more")
    }

    // MARK: - Coach-only accounts and coach rights

    @Test func coachOnlyAccountsAreNeverRanked() {
        let me = UUID(), coach = UUID(), rower = UUID()
        let ids = [me, coach, rower]
        #expect(SocialScope.ranked(ids, nonRowerIds: [coach], viewerId: me, viewerIsRower: true) == [me, rower])
        // A coach-only viewer drops out of their own boards too.
        #expect(SocialScope.ranked(ids, nonRowerIds: [coach], viewerId: me, viewerIsRower: false) == [rower])
    }

    @Test func onlyOwnersAndCoOwnersMakeCoaches() {
        #expect(ClubRole.owner.canMakeCoach)
        #expect(ClubRole.coOwner.canMakeCoach)
        #expect(!ClubRole.admin.canMakeCoach)
        #expect(!ClubRole.member.canMakeCoach)
    }

    // MARK: - Helpers

    private static func rower(
        _ name: String, squads: Set<UUID> = [], shortfall: Int = 0, daysSince: Int? = 1
    ) -> CoachRower {
        CoachRower(
            id: UUID(), displayName: name, avatarPath: nil, category: .senior, gender: .male,
            isPrivate: false, isCoach: false, squadNames: [], squadIds: squads,
            weekMetres: 0, weekSessions: 0, weeklyTargetM: 40_000, daysSinceSession: daysSince,
            twoKBestMs: nil, prediction: nil, flags: [], shortfallM: shortfall
        )
    }

    /// The smallest engine output the flags read.
    private static func prediction(
        flags: [String], twoKByTier: [String: Double], spread: Double,
        totalSeconds: Double? = nil, rangeSeconds: Double? = nil
    ) throws -> Prediction {
        let timing = totalSeconds.map { "\"predicted_total_time_seconds\": \($0)," } ?? ""
        let range = rangeSeconds.map { "\"predicted_total_time_range_seconds\": \($0)," } ?? ""
        let tiers = twoKByTier.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", ")
        let quoted = flags.map { "\"\($0)\"" }.joined(separator: ", ")
        let json = """
        {
          \(timing) \(range)
          "schema_version": "anchor-impulse/1.5",
          "confidence_score": "Medium",
          "confidence_numeric": 60,
          "confidence_factors": [],
          "load": {"trimp_lite": 0, "session_count": 0, "window_days": 30, "raw_modifier_seconds": 0,
                   "load_confidence": 0, "modifier_seconds": 0},
          "components": {},
          "effort": {"sessions_with_rpe": 0},
          "diagnostics": {"two_k_equivalent_by_tier": {\(tiers)}, "spread_seconds": \(spread),
                          "tiers_represented": \(twoKByTier.count), "warnings": []},
          "flags": [\(quoted)],
          "warnings": [],
          "recommendations": []
        }
        """
        return try JSONDecoder().decode(Prediction.self, from: Data(json.utf8))
    }
}
