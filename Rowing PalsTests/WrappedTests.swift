//
//  WrappedTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// Season Wrapped (decision 92): the database's bundle, what it works out, which terms can be chosen
/// and when one is on the Feed; and every page drawn with sample numbers ($TMPDIR/wrapped-*.png).
@MainActor
struct WrappedTests {
    private static let sample = """
    {"metres": 412000, "sessions": 58, "days": 49, "time_ms": 91800000, "longest_streak": 9,
     "biggest_week": {"start": "2026-10-12", "metres": 61000}, "busiest_month": {"start": "2026-11-01", "metres": 210000},
     "pbs": [{"key": "2k", "distance_m": 2000, "time_ms": 418700, "day": "2026-11-20"},
             {"key": "5k", "distance_m": 5000, "time_ms": 1130000, "day": "2026-10-30"}],
     "best_2k_ms": 418700, "best_2k_before_ms": 422900,
     "club_place": {"place": 3, "of": 12, "group": "senior men"},
     "trained_with": [{"user_id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "name": "Sam Cole", "sessions": 14},
                      {"user_id": "7F9619FF-8B86-D011-B42D-00C04FC964FF", "name": "Joe Fenwick", "sessions": 9}],
     "challenges_done": ["100km in November"],
     "zones": [{"zone": "UT2", "time_ms": 61000000}, {"zone": "UT1", "time_ms": 18000000}, {"zone": "AT", "time_ms": 9000000}],
     "time_of_day": {"morning": 40, "afternoon": 6, "evening": 12}}
    """

    private func wrapped() throws -> SeasonWrapped {
        try JSONDecoder().decode(SeasonWrapped.self, from: Data(Self.sample.utf8))
    }

    @Test func decodesTheSeasonAndWorksItOut() throws {
        let season = try wrapped()
        #expect(season.metres == 412_000)
        #expect(season.pbs.count == 2)
        #expect(season.twoKImprovementMs == 4200)
        #expect(season.favouriteTime == "mornings")
        #expect(season.clubPlace?.place == 3)
        #expect(!season.isEmpty)
        #expect(WrappedPage.pages(for: season).count == 6)
        let empty = try JSONDecoder().decode(SeasonWrapped.self, from: Data(#"{"metres": 0, "sessions": 0}"#.utf8))
        #expect(empty.isEmpty)
        #expect(empty.twoKImprovementMs == nil)
        #expect(empty.favouriteTime == nil)
        #expect(WrappedPage.pages(for: empty) == [.season])
    }

    @Test func termsAreNamedWithTheirYearLatestFirst() {
        let terms = [ClubTerm(id: UUID(), name: "Michaelmas", startsOn: "2026-10-05", endsOn: "2026-12-04"),
                     ClubTerm(id: UUID(), name: "Lent", startsOn: "2027-01-11", endsOn: "2027-03-12"),
                     ClubTerm(id: UUID(), name: "Easter 2026", startsOn: "2026-04-20", endsOn: "2026-06-12")]
        let periods = WrappedRules.periods(from: terms, today: "2026-11-01")
        // Lent hasn't begun; the rest, latest first.
        #expect(periods.map(\.title) == ["Michaelmas 2026", "Easter 2026"])
        #expect(WrappedRules.defaultPeriod(periods, today: "2026-11-01")?.title == "Michaelmas 2026")
        #expect(WrappedRules.isSoFar(periods[0], today: "2026-11-01"))
        #expect(!WrappedRules.isSoFar(periods[1], today: "2026-11-01"))
    }

    @Test func aTermIsOnTheFeedForThreeWeeksAfterItEnds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let terms = [ClubTerm(id: UUID(), name: "Michaelmas", startsOn: "2026-10-05", endsOn: "2026-12-04")]
        func on(_ day: Int, _ month: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 9)) ?? Date()
        }
        #expect(WrappedRules.readyTerm(terms, today: on(4, 12), calendar: calendar) == nil)
        #expect(WrappedRules.readyTerm(terms, today: on(5, 12), calendar: calendar)?.title == "Michaelmas 2026")
        #expect(WrappedRules.readyTerm(terms, today: on(25, 12), calendar: calendar) != nil)
        #expect(WrappedRules.readyTerm(terms, today: on(27, 12), calendar: calendar) == nil)
        let custom = WrappedRules.custom(from: on(10, 11), to: on(1, 11), calendar: calendar)
        #expect(custom.startsOn == "2026-11-01" && custom.endsOn == "2026-11-10" && custom.isCustom)
    }

    @Test func everyPageDraws() throws {
        let season = try wrapped()
        let period = WrappedPeriod(termId: UUID(), title: "Michaelmas 2026", startsOn: "2026-10-05", endsOn: "2026-12-04")
        for scheme in [ColorScheme.dark, .light] {
            let pages = HStack(spacing: 16) {
                ForEach(WrappedPage.allCases) { page in
                    WrappedPageView(page: page, wrapped: season, period: period, name: "Piero Ciobanu", isSoFar: false)
                }
            }
            .padding(16)
            .background(Tokens.Base.ground)
            .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: pages)
            renderer.scale = 1
            let image = try #require(renderer.uiImage)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("wrapped-\(scheme == .dark ? "dark" : "light").png")
            try #require(image.pngData()).write(to: url)
            print("Wrapped snapshot: \(url.path)")
        }
    }
}
