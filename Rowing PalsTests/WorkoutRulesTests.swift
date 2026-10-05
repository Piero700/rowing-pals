//
//  WorkoutRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import PaceEngine
import Testing
@testable import Rowing_Pals

/// Set workouts (decisions 39, 49–51): done / partly / not yet, matching rowed pieces to reps,
/// each rower's target split, the wording, and the stored shapes.
@MainActor
struct WorkoutRulesTests {
    private static func segment(
        _ distance: Int, _ timeMs: Int, label: SegmentLabel = .main, position: Int = 0,
        day: String = "2026-10-06", rep: Int? = nil
    ) -> WorkoutRules.LinkedSegment {
        WorkoutRules.LinkedSegment(
            sessionDate: day, position: position, label: label, distanceM: distance, timeMs: timeMs,
            splitMs: Int(Double(timeMs) / (Double(distance) / 500)), rate: 27, repDistanceM: rep
        )
    }

    private static let threeByTwoK = [WorkoutPiece(kind: .distance, value: 2000, reps: 3, restMs: 300_000)]

    // MARK: - Done, partly, not yet (decision 49)

    @Test func noLinkedSessionIsNotYet() {
        #expect(WorkoutRules.status(pieces: Self.threeByTwoK, segments: [], hasLinkedSession: false) == .notYet)
    }

    @Test func everyRepRowedIsDone() {
        let segments = (0..<3).map { Self.segment(2000, 410_000, position: $0) }
        #expect(WorkoutRules.status(pieces: Self.threeByTwoK, segments: segments, hasLinkedSession: true) == .done)
    }

    @Test func notCompletingTheWholeWorkoutIsPartly() {
        let segments = (0..<2).map { Self.segment(2000, 410_000, position: $0) }
        #expect(WorkoutRules.status(pieces: Self.threeByTwoK, segments: segments, hasLinkedSession: true)
            == .partly(completed: 2, total: 3))
        // A rep cut short doesn't count.
        let short = [Self.segment(2000, 410_000), Self.segment(2000, 410_000, position: 1), Self.segment(1500, 300_000, position: 2)]
        #expect(WorkoutRules.status(pieces: Self.threeByTwoK, segments: short, hasLinkedSession: true)
            == .partly(completed: 2, total: 3))
    }

    @Test func aWorkoutWithoutPiecesIsDoneByAnyLinkedSession() {
        #expect(WorkoutRules.status(pieces: [], segments: [Self.segment(5000, 1_300_000)], hasLinkedSession: true) == .done)
    }

    @Test func warmUpsAndCoolDownsNeverCount() {
        let segments = [
            Self.segment(2000, 520_000, label: .warmup, position: 0),
            Self.segment(2000, 410_000, position: 1),
            Self.segment(2000, 520_000, label: .cooldown, position: 2)
        ]
        #expect(WorkoutRules.status(pieces: Self.threeByTwoK, segments: segments, hasLinkedSession: true)
            == .partly(completed: 1, total: 3))
    }

    @Test func anIntervalPhotoCountsAsItsReps() {
        // One photo of 3 × 2,000m with a rep distance.
        let segments = [Self.segment(6000, 1_230_000, rep: 2000)]
        #expect(WorkoutRules.status(pieces: Self.threeByTwoK, segments: segments, hasLinkedSession: true) == .done)
        let reps = WorkoutRules.rowedReps(pieces: Self.threeByTwoK, segments: segments)
        #expect(reps.compactMap { $0 }.count == 3)
    }

    @Test func monitorRoundingStillCompletesARep() {
        // A 2,000m piece read as 1,985m (within 1%) and a 20:00 piece stopped at 19:58.
        #expect(WorkoutRules.covers(Self.segment(1985, 410_000), WorkoutPiece(kind: .distance, value: 2000)))
        #expect(!WorkoutRules.covers(Self.segment(1900, 400_000), WorkoutPiece(kind: .distance, value: 2000)))
        #expect(WorkoutRules.covers(Self.segment(5200, 1_198_000), WorkoutPiece(kind: .time, value: 1_200_000)))
    }

    @Test func linkedPiecesFillRepsInTheOrderTheyWereRowed() {
        let pieces = [WorkoutPiece(kind: .distance, value: 2000, reps: 1), WorkoutPiece(kind: .distance, value: 500, reps: 2)]
        let segments = [
            Self.segment(500, 95_000, position: 2),
            Self.segment(2000, 410_000, position: 0),
            Self.segment(500, 96_000, position: 3)
        ]
        let reps = WorkoutRules.rowedReps(pieces: pieces, segments: segments)
        #expect(reps.map { $0?.splitMs } == [102_500, 95_000, 96_000])
    }

    // MARK: - Targets (decision 51)

    @Test func theCoachsSplitIsEveryonesTarget() {
        let piece = WorkoutPiece(kind: .distance, value: 2000, splitMs: 102_000)
        #expect(WorkoutRules.targetSplitMs(piece: piece, zone: .at, twoKSplitSeconds: 110) == 102_000)
    }

    @Test func withoutOneEachRowerGetsTheirOwnFromTheirPredictedTwoK() throws {
        let piece = WorkoutPiece(kind: .distance, value: 16000)
        // UT2 at its own reference distance: the 2k split plus 22 s.
        #expect(WorkoutRules.targetSplitMs(piece: piece, zone: .ut2, twoKSplitSeconds: 105) == 127_000)
        let faster = try #require(WorkoutRules.targetSplitMs(piece: WorkoutPiece(kind: .distance, value: 2000), zone: .at, twoKSplitSeconds: 100))
        let slower = try #require(WorkoutRules.targetSplitMs(piece: WorkoutPiece(kind: .distance, value: 2000), zone: .at, twoKSplitSeconds: 115))
        #expect(slower - faster == 15_000)
        #expect(WorkoutRules.targetSplitMs(piece: piece, zone: .ut2, twoKSplitSeconds: nil) == nil)
    }

    @Test func aTimePieceFindsItsOwnDistance() throws {
        // 60 minutes of UT2 for a 1:45 2k: about 14 km, so close to the 16 km target.
        let target = try #require(WorkoutRules.targetSplitMs(piece: WorkoutPiece(kind: .time, value: 3_600_000), zone: .ut2, twoKSplitSeconds: 105))
        let expected = zoneTargetSplit(twoKSplit: 105, zone: .ut2, distanceM: 3600 * 500 / (Double(target) / 1000))
        #expect(abs(Double(target) / 1000 - expected) < 0.1)
    }

    @Test func aTestDayIsRowedAllOut() {
        let workout = CoachWorkout(id: UUID(), clubId: UUID(), createdBy: nil, title: "2k test", workoutDate: "2026-10-11",
                                   startTime: nil, description: nil, zone: "UT2", testKey: "2k", pieces: [], audience: .club)
        #expect(WorkoutRules.zone(of: workout) == .an)
    }

    // MARK: - Wording

    @Test func piecesReadAsTheCanvasWritesThem() {
        let piece = WorkoutPiece(kind: .distance, value: 2000, reps: 3, restMs: 300_000, rateMin: 26, rateMax: 28, splitMs: 102_000)
        #expect(WorkoutRules.pieceTitle(piece) == "2,000m × 3")
        #expect(WorkoutRules.pieceDetail(piece) == "Rest 5:00 · rate 26–28 · split 1:42")
        #expect(WorkoutRules.piecesSummary([WorkoutPiece(kind: .time, value: 3_600_000)]) == "1 × 60:00")
        #expect(WorkoutRules.deltaText(rowedMs: 112_800, targetMs: 113_000) == "−0.2")
        #expect(WorkoutRules.deltaText(rowedMs: 113_400, targetMs: 113_000) == "+0.4")
        #expect(WorkoutRules.splitText(125_000) == "2:05")
        #expect(WorkoutRules.splitTenthsText(102_000) == "1:42.0")
    }

    @Test func workoutsSortIntoTodayUpcomingAndPast() {
        func workout(_ day: String) -> CoachWorkout {
            CoachWorkout(id: UUID(), clubId: UUID(), createdBy: nil, title: "x", workoutDate: day, startTime: "06:30:00",
                         description: nil, zone: nil, testKey: nil, pieces: [], audience: .club)
        }
        #expect(WorkoutRules.section(workout("2026-10-06"), today: "2026-10-06") == .today)
        #expect(WorkoutRules.section(workout("2026-10-07"), today: "2026-10-06") == .upcoming)
        #expect(WorkoutRules.section(workout("2026-09-30"), today: "2026-10-06") == .past)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        #expect(WorkoutRules.whenText(workout("2026-10-06"), calendar: calendar) == "Tue 6 Oct · 06:30")
    }

    // MARK: - Stored shapes

    @Test func aWorkoutReadsBackWithItsPiecesAndTargets() throws {
        let squad = UUID()
        let json = """
        {"id": "\(UUID())", "club_id": "\(UUID())", "created_by": null, "title": "3 × 2,000m",
         "workout_date": "2026-10-07", "start_time": "06:30:00", "description": null, "zone": "AT",
         "test_key": null, "audience": "squads",
         "pieces": [{"kind": "distance", "value": 2000, "reps": 3, "rest_ms": 300000, "rate_min": 26, "rate_max": 28}],
         "coach_workout_targets": [{"squad_id": "\(squad)", "user_id": null}]}
        """
        let workout = try JSONDecoder().decode(CoachWorkout.self, from: Data(json.utf8))
        #expect(workout.pieces.first?.reps == 3)
        #expect(workout.pieces.first?.splitMs == nil)
        #expect(workout.squadIds == [squad])
        #expect(workout.audience == .squads)
        let encoded = try JSONEncoder().encode(workout.pieces)
        let text = String(decoding: encoded, as: UTF8.self)
        #expect(text.contains("\"rest_ms\":300000"))
        #expect(!text.contains("\"id\""))
    }

    @Test func audienceWordingNamesSquadsAndRowers() {
        let a = UUID(), b = UUID()
        let squads = CoachWorkout(id: UUID(), clubId: UUID(), createdBy: nil, title: "x", workoutDate: "2026-10-07", startTime: nil,
                                  description: nil, zone: nil, testKey: "2k", pieces: [], audience: .squads, squadIds: [a, b])
        #expect(WorkoutsText.audience(squads, squads: [a: "Senior women", b: "Senior men"], names: [:])
            == "Senior men, Senior women · test day")
        let rowers = CoachWorkout(id: UUID(), clubId: UUID(), createdBy: nil, title: "x", workoutDate: "2026-10-07", startTime: nil,
                                  description: nil, zone: nil, testKey: nil, pieces: [], audience: .rowers, rowerIds: [a, b, UUID()])
        #expect(WorkoutsText.audience(rowers, squads: [:], names: [a: "Tom", b: "Ann"]) == "Ann and Tom")
    }
}
