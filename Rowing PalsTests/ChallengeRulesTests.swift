//
//  ChallengeRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Challenges and erg events (decision 91): whether one's on, days left, each kind's standings,
/// which pieces count for an event and the board's order.
struct ChallengeRulesTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return calendar
    }()

    private func challenge(_ kind: ChallengeKind = .target, target: Int? = 100_000, squads: [UUID] = [],
                           from: String = "2026-11-01", to: String = "2026-11-30") -> Challenge {
        Challenge(id: UUID(), clubId: UUID(), kind: kind, title: "Test", targetM: target, squadIds: squads, startsOn: from, endsOn: to)
    }

    private func day(_ text: String, hour: Int = 9) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: hour)) ?? Date()
    }

    @Test func aChallengeIsOnFromItsFirstDayToItsLast() {
        let november = challenge()
        #expect(ChallengeRules.status(november, today: "2026-10-31") == .upcoming)
        #expect(ChallengeRules.status(november, today: "2026-11-01") == .running)
        #expect(ChallengeRules.status(november, today: "2026-11-30") == .running)
        #expect(ChallengeRules.status(november, today: "2026-12-01") == .finished)
    }

    @Test func daysLeftCountTodayAndStopAtTheEnd() {
        let november = challenge()
        #expect(ChallengeRules.daysLeft(november, now: day("2026-11-01"), calendar: calendar) == 30)
        #expect(ChallengeRules.daysLeft(november, now: day("2026-11-28"), calendar: calendar) == 3)
        #expect(ChallengeRules.daysLeft(november, now: day("2026-11-30", hour: 23), calendar: calendar) == 1)
        #expect(ChallengeRules.daysLeft(november, now: day("2026-12-02"), calendar: calendar) == 0)
        // Before it starts: its whole length.
        #expect(ChallengeRules.daysLeft(november, now: day("2026-10-20"), calendar: calendar) == 30)
        #expect(ChallengeRules.day(day("2026-11-05"), calendar: calendar) == "2026-11-05")
    }

    @Test func aPersonalTargetRanksEveryoneAndTicksThoseDone() {
        let rows = [ChallengeStanding(userId: UUID(), displayName: "Sam", metres: 40_000),
                    ChallengeStanding(userId: UUID(), displayName: "Ella", metres: 120_000),
                    ChallengeStanding(userId: UUID(), displayName: "Joe", metres: 0)]
        let ranked = ChallengeRules.targetRows(rows, target: 100_000)
        #expect(ranked.map(\.standing.displayName) == ["Ella", "Sam", "Joe"])
        #expect(ranked.map(\.isDone) == [true, false, false])
        #expect(ranked[0].progress == 1)
        #expect(ranked[1].progress == 0.4)
    }

    @Test func aClubTotalAddsEveryoneUpAndListsWhoRowed() {
        let rows = [ChallengeStanding(userId: UUID(), displayName: "Sam", metres: 40_000),
                    ChallengeStanding(userId: UUID(), displayName: "Ella", metres: 60_000),
                    ChallengeStanding(userId: UUID(), displayName: "Joe", metres: 0)]
        #expect(ChallengeRules.clubTotal(rows) == 100_000)
        #expect(ChallengeRules.contributors(rows).map(\.displayName) == ["Ella", "Sam"])
    }

    @Test func squadsRaceOnMetresPerRowerNotSize() {
        let seniors = Squad(id: UUID(), name: "Seniors", memberIds: [])
        let novices = Squad(id: UUID(), name: "Novices", memberIds: [])
        let rows = [
            // Seniors: 3 rowers, 90,000 in all, 30,000 a rower.
            ChallengeStanding(userId: UUID(), displayName: "A", metres: 30_000, squadIds: [seniors.id]),
            ChallengeStanding(userId: UUID(), displayName: "B", metres: 30_000, squadIds: [seniors.id]),
            ChallengeStanding(userId: UUID(), displayName: "C", metres: 30_000, squadIds: [seniors.id]),
            // Novices: 2 rowers, 80,000 in all, 40,000 a rower — fewer metres, but ahead.
            ChallengeStanding(userId: UUID(), displayName: "D", metres: 50_000, squadIds: [novices.id]),
            ChallengeStanding(userId: UUID(), displayName: "E", metres: 30_000, squadIds: [novices.id]),
            ChallengeStanding(userId: UUID(), displayName: "F", metres: 99_000)
        ]
        let ranked = ChallengeRules.squadRows(rows, squads: [seniors, novices], ids: [seniors.id, novices.id])
        #expect(ranked.map(\.name) == ["Novices", "Seniors"])
        #expect(ranked.map(\.perRowerM) == [40_000, 30_000])
        #expect(ranked.map(\.totalM) == [80_000, 90_000])
        // A squad no longer there is left out.
        #expect(ChallengeRules.squadRows(rows, squads: [seniors], ids: [seniors.id, novices.id]).count == 1)
    }

    @Test func theProgressLineSaysWhereYouAre() throws {
        let me = UUID()
        let rows = [ChallengeStanding(userId: me, displayName: "Me", metres: 120_000)]
        let done = try #require(ChallengeText.progress(in: challenge(), standings: rows, squads: [], viewerId: me))
        #expect(done.isDone)
        #expect(done.text.hasPrefix("Done · "))
        let total = try #require(ChallengeText.progress(in: challenge(.clubTotal, target: 240_000), standings: rows, squads: [], viewerId: me))
        #expect(total.fraction == 0.5)
        #expect(!total.isDone)
    }

    // MARK: - Erg events

    private func event(distance: Int? = 2000, duration: Int? = nil) -> ErgEvent {
        ErgEvent(id: UUID(), clubId: UUID(), title: "Club 2k day", distanceM: distance, durationMs: duration,
                 startsAt: day("2026-11-07", hour: 9), endsAt: day("2026-11-07", hour: 12))
    }

    @Test func anEventTakesItsPieceOnly() {
        let twoK = event()
        #expect(twoK.pieceLabel == "2k")
        #expect(twoK.accepts(distanceM: 2000, timeMs: 420_000))
        #expect(!twoK.accepts(distanceM: 1999, timeMs: 420_000))
        let thirty = event(distance: nil, duration: 30 * 60_000)
        #expect(thirty.pieceLabel == "30min")
        #expect(thirty.accepts(distanceM: 8000, timeMs: 30 * 60_000 + 1500))
        #expect(!thirty.accepts(distanceM: 8000, timeMs: 30 * 60_000 + 30_000))
        #expect(ErgEvent.pieceLabel(distanceM: 750, durationMs: nil) == "750m")
        #expect(ErgEvent.pieceLabel(distanceM: nil, durationMs: 90_000) == "1min 30s")
    }

    @Test func anEventTakesPostsUntilSixHoursAfterItEnds() {
        let twoK = event()
        #expect(!twoK.isOpenForPosting(at: day("2026-11-07", hour: 8)))
        #expect(twoK.isOpenForPosting(at: day("2026-11-07", hour: 10)))
        #expect(twoK.isOpenForPosting(at: day("2026-11-07", hour: 17)))
        #expect(!twoK.isOpenForPosting(at: day("2026-11-07", hour: 19)))
        #expect(ChallengeRules.eventStatus(twoK, now: day("2026-11-07", hour: 13)) == .finished)
    }

    @Test func theBoardIsFastestFirstForADistanceAndFurthestForATime() {
        func result(_ name: String, _ distance: Int, _ time: Int) -> ErgEventResult {
            ErgEventResult(userId: UUID(), displayName: name, gender: nil, category: nil, distanceM: distance, timeMs: time, sessionId: UUID())
        }
        let rows = [result("Slow", 2000, 430_000), result("Fast", 2000, 401_000)]
        #expect(ChallengeRules.eventBoard(rows, event: event()).map(\.displayName) == ["Fast", "Slow"])
        let timed = [result("Short", 7800, 1_800_000), result("Long", 8100, 1_800_000)]
        #expect(ChallengeRules.eventBoard(timed, event: event(distance: nil, duration: 1_800_000)).map(\.displayName) == ["Long", "Short"])
        #expect(rows[1].splitMs == 100_250)
    }
}
