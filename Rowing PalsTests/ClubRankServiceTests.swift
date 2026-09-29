//
//  ClubRankServiceTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The ranking rule behind another rower's "Club rankings" card (decision 20).
struct ClubRankServiceTests {
    private let alice = UUID()
    private let tom = UUID()
    private let jack = UUID()
    private let nina = UUID()

    @Test func moreMetresRanksHigher() {
        let metres = [alice: 98_300, tom: 120_000, jack: 40_000]
        #expect(ClubRankService.rank(of: alice, in: metres, higherIsBetter: true) == 2)
        #expect(ClubRankService.rank(of: tom, in: metres, higherIsBetter: true) == 1)
        #expect(ClubRankService.rank(of: jack, in: metres, higherIsBetter: true) == 3)
    }

    @Test func fasterTimeRanksHigher() {
        let twoK = [alice: 424_100, tom: 380_000, jack: 450_000]
        #expect(ClubRankService.rank(of: alice, in: twoK, higherIsBetter: false) == 2)
        #expect(ClubRankService.rank(of: tom, in: twoK, higherIsBetter: false) == 1)
    }

    @Test func equalResultsShareAPlace() {
        let metres = [alice: 50_000, tom: 50_000, jack: 60_000, nina: 10_000]
        #expect(ClubRankService.rank(of: alice, in: metres, higherIsBetter: true) == 2)
        #expect(ClubRankService.rank(of: tom, in: metres, higherIsBetter: true) == 2)
        #expect(ClubRankService.rank(of: nina, in: metres, higherIsBetter: true) == 4)
    }

    @Test func noResultMeansNoRank() {
        #expect(ClubRankService.rank(of: nina, in: [alice: 1], higherIsBetter: true) == nil)
    }

    @Test func weeksStartOnMonday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        // Wednesday 30 September 2026 → Monday 28 September.
        let wednesday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 12)))
        #expect(ClubRankService.weekStartString(for: wednesday) == "2026-09-28")
        // Sunday 4 October still belongs to the week starting 28 September.
        let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 12)))
        #expect(ClubRankService.weekStartString(for: sunday) == "2026-09-28")
    }
}
