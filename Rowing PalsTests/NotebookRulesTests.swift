//
//  NotebookRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The coach's Notebook and the rower's Feed card (decision 96, NP4): which workouts get a page, a
/// page's rows (the coach's score winning over the post, erg order, the squad filter), its averages
/// and against-target figures, one rower's line, and which noted scores reach the rower's Feed.
@MainActor
struct NotebookRulesTests {
    private static let a = UUID(), b = UUID(), c = UUID()
    private static let rowers = [
        NotebookRules.Rower(id: a, name: "Amy M."),
        NotebookRules.Rower(id: b, name: "Ben C."),
        NotebookRules.Rower(id: c, name: "Cal D."),
    ]
    private static let threeByTwoK = [WorkoutPiece(kind: .distance, value: 2000, reps: 3)]

    private static func workout(_ day: String = "2026-10-28", title: String = "3 × 2,000m", testKey: String? = nil,
                                pieces: [WorkoutPiece]? = nil) -> CoachWorkout {
        CoachWorkout(id: UUID(), clubId: UUID(), createdBy: nil, title: title, workoutDate: day, startTime: "17:30:00",
                     description: nil, zone: "AT", testKey: testKey, pieces: pieces ?? threeByTwoK, audience: .club)
    }

    private static func session(_ rower: UUID, splits: [Int], workout: CoachWorkout) -> WorkoutService.LinkedSession {
        WorkoutService.LinkedSession(id: UUID(), userId: rower, workoutId: workout.id, segments: splits.enumerated().map { index, split in
            WorkoutRules.LinkedSegment(sessionDate: workout.workoutDate, position: index, label: .main, distanceM: 2000,
                                       timeMs: split * 4, splitMs: split, rate: 27, repDistanceM: nil)
        })
    }

    private static func score(_ rower: UUID, _ rep: Int, _ split: Int?, workout: CoachWorkout, satOut: Bool = false) -> NotepadScore {
        NotepadScore(workoutId: workout.id, userId: rower, pieceIndex: rep, splitMs: satOut ? nil : split, satOut: satOut)
    }

    private static func source(_ workout: CoachWorkout, sessions: [WorkoutService.LinkedSession] = [],
                               scores: [NotepadScore] = [], notepad: CoachNotepad? = nil,
                               audience: Set<UUID>? = nil) -> NotebookRules.Source {
        NotebookRules.Source(workout: workout, pieces: NotepadRules.pieces(of: workout), audience: audience ?? [a, b, c],
                             sessions: sessions, notepad: notepad, scores: scores)
    }

    // MARK: - Which workouts get a page

    @Test func aWorkoutWithNothingOnItHasNoPage() {
        #expect(!NotebookRules.hasPage(Self.source(Self.workout())))
        let w = Self.workout()
        #expect(NotebookRules.hasPage(Self.source(w, sessions: [Self.session(Self.a, splits: [104_000], workout: w)])))
        #expect(NotebookRules.hasPage(Self.source(w, scores: [Self.score(Self.a, 0, 104_000, workout: w)])))
    }

    // MARK: - A page

    @Test func theCoachsScoreWinsOverThePostAndSourcesAreCountedOnce() {
        let w = Self.workout()
        let page = NotebookRules.page(Self.source(
            w,
            sessions: [Self.session(Self.a, splits: [104_000, 105_000, 106_000], workout: w),
                       Self.session(Self.b, splits: [103_000, 103_000, 103_000], workout: w)],
            scores: [Self.score(Self.b, 1, 101_000, workout: w),
                     Self.score(Self.c, 0, nil, workout: w, satOut: true),
                     Self.score(Self.c, 1, nil, workout: w, satOut: true),
                     Self.score(Self.c, 2, nil, workout: w, satOut: true)]
        ), rowers: Self.rowers)
        let amy = page.rows.first { $0.rowerId == Self.a }
        let ben = page.rows.first { $0.rowerId == Self.b }
        #expect(amy?.splits == [104_000, 105_000, 106_000])
        #expect(amy?.average == 105_000)
        #expect(ben?.splits == [103_000, 101_000, 103_000])
        #expect(page.rows.first { $0.rowerId == Self.c }?.isAllSatOut == true)
        #expect(page.sourcesText == "1 posted · 1 you noted · 1 sat out")
    }

    @Test func rowsFollowTheSavedErgOrderThenNames() {
        let w = Self.workout()
        let notepad = CoachNotepad(workoutId: w.id, clubId: w.clubId, blocks: [], notes: "Rates high.", rowerOrder: [Self.c, Self.a])
        let page = NotebookRules.page(Self.source(w, notepad: notepad), rowers: Self.rowers)
        #expect(page.rows.map(\.rowerId) == [Self.c, Self.a, Self.b])
        #expect(page.notes == "Rates high.")
    }

    @Test func aSquadShowsOnlyItsRowers() {
        let page = NotebookRules.page(Self.source(Self.workout()), rowers: Self.rowers, squad: [Self.b])
        #expect(page.rows.map(\.rowerId) == [Self.b])
        // Rowers not in the workout never show, whatever the squad.
        let small = NotebookRules.page(Self.source(Self.workout(), audience: [Self.a]), rowers: Self.rowers)
        #expect(small.rows.map(\.rowerId) == [Self.a])
    }

    @Test func squadAveragesAndAgainstTarget() {
        let w = Self.workout()
        let page = NotebookRules.page(Self.source(
            w, sessions: [Self.session(Self.a, splits: [104_000, 104_000, 104_000], workout: w),
                          Self.session(Self.b, splits: [100_000, 100_000, 100_000], workout: w)]
        ), rowers: Self.rowers) { _, _ in 102_000 }
        #expect(page.squadSplits == [102_000, 102_000, 102_000])
        #expect(page.squadAverage == 102_000)
        let amy = page.rows.first { $0.rowerId == Self.a }
        #expect(amy?.averageDelta == 2000)
        #expect(page.rows.first { $0.rowerId == Self.b }?.averageDelta == -2000)
        #expect(page.squadAverageDelta == 0)
        #expect(NotebookRules.deltaText(2000) == "+2.0")
        #expect(NotebookRules.deltaText(-1500) == "−1.5")
    }

    @Test func aTestPageShowsTheTime() {
        let w = Self.workout(title: "2k test", testKey: "2k", pieces: [])
        let page = NotebookRules.page(Self.source(w, scores: [Self.score(Self.a, 0, 105_000, workout: w)]), rowers: Self.rowers)
        #expect(page.isTest)
        #expect(page.rows.first { $0.rowerId == Self.a }?.timeMs == 420_000)
        #expect(page.rows.first { $0.rowerId == Self.b }?.timeMs == nil)
    }

    // MARK: - One rower's line

    @Test func aRowersLineIsNewestFirstAndTodayIsntCounted() {
        let old = Self.workout("2026-10-21"), recent = Self.workout("2026-10-28"), today = Self.workout("2026-11-05")
        let pages = [
            NotebookRules.page(Self.source(old, sessions: [Self.session(Self.a, splits: [106_000, 106_000, 106_000], workout: old)]),
                               rowers: Self.rowers) { _, _ in 105_000 },
            NotebookRules.page(Self.source(recent, scores: [Self.score(Self.a, 0, 99_000, workout: recent)]),
                               rowers: Self.rowers) { _, _ in 100_000 },
            NotebookRules.page(Self.source(today, scores: [Self.score(Self.a, 0, 90_000, workout: today)]), rowers: Self.rowers),
        ]
        let lines = NotebookRules.lines(for: Self.a, pages: pages, today: [today.id])
        #expect(lines.map(\.page.workout.workoutDate) == ["2026-11-05", "2026-10-28", "2026-10-21"])
        #expect(lines.first?.isToday == true)
        let summary = NotebookRules.summary(lines)
        #expect(summary.done == 2)
        #expect(summary.of == 2)
        // +1.0 on the old page, −1.0 on the recent one.
        #expect(summary.averageDelta == 0)
        // Today's 1:30.0 is still being written, so the fastest is 1:39.0.
        #expect(summary.fastestMs == 99_000)
    }

    // MARK: - The rower's Feed card

    private static func card(_ day: String, splits: [Int?]) -> CoachNotedScores {
        CoachNotedScores(workoutId: UUID(), title: "3 × 2,000m", workoutDate: day, pieces: threeByTwoK, testKey: nil,
                         coachName: "Tom Ashworth", clubName: "UEA Boat Club", erg: 3,
                         scores: splits.enumerated().map { CoachNotedScores.Piece(index: $0.offset, splitMs: $0.element, satOut: $0.element == nil) },
                         postedAverageMs: nil)
    }

    @Test func aCardShowsForThreeDaysAfterTheWorkout() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12)) ?? Date()
        let since = NotepadRules.rowerCardSince(today: today, calendar: calendar)
        #expect(since == "2026-11-02")
        let cards = [Self.card("2026-11-05", splits: [103_500]), Self.card("2026-11-02", splits: [104_000]),
                     Self.card("2026-11-01", splits: [104_000]), Self.card("2026-11-06", splits: [104_000])]
        #expect(NotepadRules.rowerCards(cards, today: "2026-11-05", since: since).map(\.workoutDate) == ["2026-11-05", "2026-11-02"])
    }

    @Test func aCardNeedsAtLeastOneSplit() {
        let cards = [Self.card("2026-11-05", splits: [nil, nil]), Self.card("2026-11-04", splits: [nil, 104_000])]
        #expect(NotepadRules.rowerCards(cards, today: "2026-11-05", since: "2026-11-02").map(\.workoutDate) == ["2026-11-04"])
    }

    @Test func aCardsPiecesComeFromItsWorkout() {
        #expect(NotepadRules.reps(NotepadRules.pieces(set: [], title: "4 x 500m", testKey: nil)).count == 1)
        #expect(NotepadRules.pieces(set: [], title: "2k test", testKey: "2k").first?.value == 2000)
        #expect(NotepadRules.reps(NotepadRules.pieces(set: Self.threeByTwoK, title: "anything", testKey: nil)).count == 3)
    }
}
