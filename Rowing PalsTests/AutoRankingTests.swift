//
//  AutoRankingTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Decision 104: any photographed Main or Extra piece, or interval rep, at a test's distance or
/// time ranks automatically; the session's best per test; warm-ups, cool-downs and interval
/// totals never rank; and a next screen of the same workout joins its reps onto the piece.
struct AutoRankingTests {
    private static let tests = StandardTest.all
    private static func test(_ key: String) -> StandardTest { StandardTest.all.first { $0.key == key }! }

    private static func piece(
        _ label: SegmentLabel = .main, distanceM: Int, timeMs: Int,
        reps: [(Int, Int)] = [], isInterval: Bool = false
    ) -> AutoRanking.Piece {
        AutoRanking.Piece(segmentId: UUID(), label: label, distanceM: distanceM, timeMs: timeMs,
                          isInterval: isInterval, reps: reps.map { (distanceM: $0.0, timeMs: $0.1) })
    }

    // MARK: Whole pieces

    @Test func aSteadyThirtyMinutesRanksOnTheThirtyMinuteBoard() {
        // The user's 30 minutes at rate 20: 7,929 m, posted as Training.
        let results = AutoRanking.results(for: [Self.piece(distanceM: 7929, timeMs: 1_800_000)], tests: Self.tests)
        #expect(results.map(\.key) == ["30min"])
        #expect(results.first?.distanceM == 7929)
        #expect(results.first?.splitMs == 113_507)
    }

    @Test func warmUpsAndCoolDownsNeverRank() {
        let results = AutoRanking.results(for: [
            Self.piece(.warmup, distanceM: 2000, timeMs: 540_000),
            Self.piece(.cooldown, distanceM: 2000, timeMs: 560_000)
        ], tests: Self.tests)
        #expect(results.isEmpty)
    }

    @Test func extraPiecesRankAndTheSessionsBestWins() {
        let main = Self.piece(distanceM: 2000, timeMs: 420_000)
        let extra = Self.piece(.extra, distanceM: 2000, timeMs: 415_000)
        let results = AutoRanking.results(for: [main, extra], tests: Self.tests)
        #expect(results.count == 1)
        #expect(results.first?.segmentId == extra.segmentId)
        #expect(results.first?.timeMs == 415_000)
    }

    @Test func aPieceOffATestDistanceDoesNotRank() {
        #expect(AutoRanking.results(for: [Self.piece(distanceM: 2010, timeMs: 425_000)], tests: Self.tests).isEmpty)
        // 29:40 is outside a 30-minute test's 18 s finish tolerance (29:50 would be inside it).
        #expect(AutoRanking.results(for: [Self.piece(distanceM: 7900, timeMs: 1_780_000)], tests: Self.tests).isEmpty)
    }

    // MARK: Interval reps

    @Test func theBestRepOfTenFiveHundredsRanksAndTheTotalDoesNot() {
        let reps = [(500, 95_000), (500, 93_400), (500, 94_100), (500, 96_000), (500, 92_800),
                    (500, 93_900), (500, 94_500), (500, 95_200), (500, 93_000), (500, 94_000)]
        let results = AutoRanking.results(for: [
            Self.piece(distanceM: 5000, timeMs: 942_900, reps: reps, isInterval: true)
        ], tests: Self.tests)
        // 10 × 500m is not a 5k.
        #expect(results.map(\.key) == ["500m"])
        #expect(results.first?.timeMs == 92_800)
    }

    @Test func timedRepsRankOnTheirTimedTest() {
        // 3 × 4:00: the furthest rep counts on the 4min board.
        let reps = [(1180, 240_000), (1195, 240_000), (1172, 240_000)]
        let results = AutoRanking.results(for: [
            Self.piece(distanceM: 3547, timeMs: 720_000, reps: reps, isInterval: true)
        ], tests: Self.tests)
        #expect(results.map(\.key) == ["4min"])
        #expect(results.first?.distanceM == 1195)
    }

    @Test func clubTestsRankToo() {
        let club = StandardTest(key: "club:abc", label: "750m", target: .distance(m: 750))
        let results = AutoRanking.results(for: [Self.piece(distanceM: 750, timeMs: 150_000)], tests: Self.tests + [club])
        #expect(results.map(\.key) == ["club:abc"])
    }

    // MARK: New PBs

    @Test func theFirstResultIsAPBAndASlowerOneIsNot() {
        let result = AutoRanking.Result(key: "2k", segmentId: UUID(), distanceM: 2000, timeMs: 420_000)
        #expect(AutoRanking.isNewBest(result, test: Self.test("2k"), previous: []))
        #expect(AutoRanking.isNewBest(result, test: Self.test("2k"), previous: [(2000, 421_000)]))
        #expect(!AutoRanking.isNewBest(result, test: Self.test("2k"), previous: [(2000, 419_000)]))
        let further = AutoRanking.Result(key: "30min", segmentId: UUID(), distanceM: 8000, timeMs: 1_800_000)
        #expect(AutoRanking.isNewBest(further, test: Self.test("30min"), previous: [(7929, 1_800_000)]))
        #expect(!AutoRanking.isNewBest(further, test: Self.test("30min"), previous: [(8100, 1_800_000)]))
    }

    // MARK: Review: reps, and joining the next screen

    private static func intervalFields(total: (Int, Int), reps: [MonitorRow]) -> ParsedMonitorFields {
        var fields = ParsedMonitorFields(
            elapsedTimeMs: MonitorField(value: total.1, confidence: 1),
            distanceM: MonitorField(value: total.0, confidence: 1),
            splitMs: MonitorField(value: 94_000, confidence: 1),
            rate: MonitorField(value: 30, confidence: 1),
            repDistanceM: 500,
            isIntervalWorkout: true
        )
        fields.repRows = reps
        return fields
    }

    private static func rep(_ number: Int, _ timeMs: Int) -> MonitorRow {
        MonitorRow(timeMs: timeMs, distanceM: 500, splitMs: timeMs, rate: 30, number: number)
    }

    @MainActor @Test func theNextScreenOfTheSameWorkoutJoinsItsReps() {
        let vm = ReviewSheetViewModel(selfieJPEG: nil, isLiveCapture: true, startsBlank: false)
        let first = Self.intervalFields(total: (5000, 942_900), reps: (1...5).map { Self.rep($0, 95_000) })
        vm.segments.append(DraftSegment(label: .main, photoJPEG: Data([0]), fields: first))
        #expect(vm.segments[0].expectedRepCount == 10)

        // Reps 5 to 10: rep 5 is on both screens and kept once; rep 9 is the best.
        var second = (5...10).map { Self.rep($0, 95_000) }
        second[4] = Self.rep(9, 92_800)
        #expect(vm.joinNextScreen(Self.intervalFields(total: (5000, 942_900), reps: second)))
        #expect(vm.segments.count == 1)
        #expect(vm.segments[0].postedReps.count == 10)
        #expect(vm.autoRankedResults.map(\.key) == ["500m"])
        #expect(vm.autoRankedResults.first?.timeMs == 92_800)
    }

    @MainActor @Test func aDifferentWorkoutIsANewPieceNotAJoin() {
        let vm = ReviewSheetViewModel(selfieJPEG: nil, isLiveCapture: true, startsBlank: false)
        vm.segments.append(DraftSegment(label: .main, photoJPEG: Data([0]),
                                        fields: Self.intervalFields(total: (5000, 942_900), reps: [Self.rep(1, 95_000)])))
        #expect(!vm.joinNextScreen(Self.intervalFields(total: (4000, 760_000), reps: [Self.rep(1, 95_000)])))
        #expect(vm.segments[0].postedReps.count == 1)
    }
}
