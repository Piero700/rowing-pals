//
//  NotepadRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The coach notepad's rules (decision 96): a page's columns, what each box shows, the order Next
/// walks in, erg order, turning a typed time or metres into a split, and the limits on blocks.
@MainActor
struct NotepadRulesTests {
    private static let workout = UUID()
    private static let a = UUID(), b = UUID(), c = UUID(), d = UUID()
    private static let twoK = WorkoutPiece(kind: .distance, value: 2000, reps: 3)
    private static let tenMinutes = WorkoutPiece(kind: .time, value: 600_000, reps: 2)

    private static func score(_ rower: UUID, _ rep: Int, split: Int? = 104_600, satOut: Bool = false) -> NotepadScore {
        NotepadScore(workoutId: workout, userId: rower, pieceIndex: rep, splitMs: satOut ? nil : split, satOut: satOut)
    }

    // MARK: - Columns

    @Test func everyRepIsAColumn() {
        let reps = NotepadRules.reps([Self.twoK, WorkoutPiece(kind: .distance, value: 500, reps: 1)])
        #expect(reps.count == 4)
        #expect(reps[2]?.value == 2000)
        #expect(reps[3]?.value == 500)
    }

    @Test func aWorkoutWithoutPiecesStillHasOneColumn() {
        let reps = NotepadRules.reps([])
        #expect(reps.count == 1)
        #expect(reps[0] == nil)
    }

    // MARK: - Boxes

    @Test func theCoachsScoreWinsOverThePostOnTheNotepad() {
        #expect(NotepadRules.cell(noted: Self.score(Self.a, 0, split: 103_000), postedSplitMs: 104_000) == .noted(splitMs: 103_000))
        #expect(NotepadRules.cell(noted: nil, postedSplitMs: 104_000) == .posted(splitMs: 104_000))
        #expect(NotepadRules.cell(noted: nil, postedSplitMs: nil) == .empty)
        #expect(NotepadRules.cell(noted: Self.score(Self.a, 0, satOut: true), postedSplitMs: 104_000) == .satOut)
    }

    // MARK: - Next

    @Test func nextWalksDownTheErgsOnTheSamePiece() {
        let order = [Self.a, Self.b, Self.c]
        let next = NotepadRules.next(after: .init(rowerId: Self.a, rep: 1), order: order, repCount: 3) { _ in .empty }
        #expect(next == .init(rowerId: Self.b, rep: 1))
    }

    @Test func nextSkipsAnyoneSatOutOnThatPiece() {
        let order = [Self.a, Self.b, Self.c]
        let next = NotepadRules.next(after: .init(rowerId: Self.a, rep: 0), order: order, repCount: 3) { spot in
            spot.rowerId == Self.b ? .satOut : .empty
        }
        #expect(next == .init(rowerId: Self.c, rep: 0))
    }

    @Test func nextStillStopsOnAFilledBoxOnTheSamePiece() {
        // Walking the line, the coach may want to correct a number already there.
        let order = [Self.a, Self.b]
        let next = NotepadRules.next(after: .init(rowerId: Self.a, rep: 0), order: order, repCount: 2) { spot in
            spot.rowerId == Self.b ? .posted(splitMs: 104_000) : .empty
        }
        #expect(next == .init(rowerId: Self.b, rep: 0))
    }

    @Test func afterTheLastErgNextGoesToTheFirstEmptyBoxOfTheNextPiece() {
        let order = [Self.a, Self.b, Self.c, Self.d]
        let filled: Set<UUID> = [Self.a, Self.b]
        let next = NotepadRules.next(after: .init(rowerId: Self.d, rep: 0), order: order, repCount: 3) { spot in
            spot.rep == 1 && filled.contains(spot.rowerId) ? .noted(splitMs: 104_000) : .empty
        }
        #expect(next == .init(rowerId: Self.c, rep: 1))
    }

    @Test func nextSkipsAPieceWithNoEmptyBoxesAndSatOutRowers() {
        let order = [Self.a, Self.b]
        let next = NotepadRules.next(after: .init(rowerId: Self.b, rep: 0), order: order, repCount: 3) { spot in
            switch (spot.rep, spot.rowerId) {
            case (1, _): .noted(splitMs: 104_000)
            case (2, Self.a): .satOut
            default: .empty
            }
        }
        #expect(next == .init(rowerId: Self.b, rep: 2))
    }

    @Test func nextIsNilWhenThePageIsFull() {
        let next = NotepadRules.next(after: .init(rowerId: Self.b, rep: 1), order: [Self.a, Self.b], repCount: 2) { _ in
            .noted(splitMs: 104_000)
        }
        #expect(next == nil)
    }

    // MARK: - Erg order

    @Test func placedRowersComeFirstThenEveryoneElseByName() {
        let rowers = [(id: Self.a, name: "Will Ng"), (id: Self.b, name: "Ben Carter"), (id: Self.c, name: "Ollie Hart"),
                      (id: Self.d, name: "Amy Moss")]
        let gone = UUID()
        let order = NotepadRules.ordered(rowers, savedOrder: [Self.c, gone, Self.a, Self.c])
        #expect(order == [Self.c, Self.a, Self.d, Self.b])
    }

    @Test func movingARowerDownAndUp() {
        let rowers = [Self.a, Self.b, Self.c, Self.d]
        #expect(NotepadRules.moved(rowers, from: [0], to: 3) == [Self.b, Self.c, Self.a, Self.d])
        #expect(NotepadRules.moved(rowers, from: [3], to: 0) == [Self.d, Self.a, Self.b, Self.c])
        #expect(NotepadRules.moved(rowers, from: [1], to: 4) == [Self.a, Self.c, Self.d, Self.b])
    }

    @Test func shortNames() {
        #expect(NotepadRules.shortName("Ollie Hart") == "Ollie H.")
        #expect(NotepadRules.shortName("Nina de la Cruz") == "Nina C.")
        #expect(NotepadRules.shortName("Priya") == "Priya")
    }

    // MARK: - Typing a score

    @Test func aDistancePieceTakesTheSplitOrTheTime() {
        #expect(NotepadRules.modes(for: Self.twoK) == [.split, .time])
        #expect(NotepadRules.modes(for: Self.tenMinutes) == [.split, .metres])
        #expect(NotepadRules.modes(for: nil) == [.split])
    }

    @Test func aTimeOffTheMonitorBecomesTheSplit() {
        // 6:58.4 for 2,000m is 1:44.6 /500m.
        let entry = NotepadRules.entry(418_400, mode: .time, piece: Self.twoK)
        #expect(entry == NotepadRules.Entry(splitMs: 104_600, timeMs: 418_400, distanceM: nil))
    }

    @Test func metresInATimedPieceBecomeTheSplit() {
        // 2,830m in 10:00 is 1:46.0 /500m.
        let entry = NotepadRules.entry(2830, mode: .metres, piece: Self.tenMinutes)
        #expect(entry?.splitMs == 106_000)
        #expect(entry?.distanceM == 2830)
    }

    @Test func aSplitIsKeptToTheTenth() {
        #expect(NotepadRules.entry(104_600, mode: .split, piece: Self.twoK)?.splitMs == 104_600)
        #expect(NotepadRules.entry(104_640, mode: .split, piece: nil)?.splitMs == 104_600)
    }

    @Test func impossibleSplitsAreRefused() {
        #expect(NotepadRules.entry(29_000, mode: .split, piece: Self.twoK) == nil)
        #expect(NotepadRules.entry(601_000, mode: .split, piece: Self.twoK) == nil)
        #expect(NotepadRules.entry(0, mode: .split, piece: Self.twoK) == nil)
        // A time typed for a timed piece has no distance to divide by.
        #expect(NotepadRules.entry(418_400, mode: .time, piece: Self.tenMinutes) == nil)
    }

    @Test func typedThroughDurationEntryAsTheCoachWouldTypeIt() throws {
        // 1 4 4 . 6 on the decimal pad (decisions 53, 56).
        let typed = DurationEntry.entry(from: "144.6", allowsTenths: true)
        let ms = try #require(DurationEntry.milliseconds(entry: typed))
        #expect(NotepadRules.entry(ms, mode: .split, piece: Self.twoK)?.splitMs == 104_600)
    }

    @Test func rates() {
        #expect(NotepadRules.rate("27") == 27)
        #expect(NotepadRules.rate("") == nil)
        #expect(NotepadRules.rate("9") == nil)
        #expect(NotepadRules.rate("80") == nil)
    }

    // MARK: - Blocks

    @Test func aNewTableHasHeadingsAndTwoRows() {
        let table = NotepadRules.newTable()
        #expect(table.kind == .table)
        #expect(table.cells.count == 3)
        #expect(table.cells[0] == ["Rower", "Technique", "Next time"])
    }

    @Test func columnsStopAtFive() {
        var table = NotepadRules.newTable()
        table = NotepadRules.addingColumn(to: table)
        #expect(table.cells[0].last == "Column 4")
        #expect(table.cells[1].count == 4)
        table = NotepadRules.addingColumn(to: table)
        table = NotepadRules.addingColumn(to: table)
        #expect(table.cells[0].count == NotepadRules.maxTableColumns)
    }

    @Test func rowsStopAtFifty() {
        var table = NotepadRules.newTable()
        for _ in 0..<60 { table = NotepadRules.addingRow(to: table) }
        #expect(table.cells.count - 1 == NotepadRules.maxTableRows)
        #expect(table.cells.last?.count == 3)
    }

    @Test func aPageHoldsUpToThirtyBlocks() {
        let full = Array(repeating: NotepadRules.newText(), count: NotepadRules.maxBlocks)
        #expect(!NotepadRules.canAddBlock(full))
        #expect(NotepadRules.canAddBlock(Array(full.dropLast())))
    }

    @Test func blocksRoundTripThroughTheirStoredShape() throws {
        let blocks = [NotepadBlock(kind: .text, text: "Ratio!"), NotepadRules.newTable()]
        let data = try JSONEncoder().encode(blocks)
        let back = try JSONDecoder().decode([NotepadBlock].self, from: data)
        #expect(back == blocks)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("\"cells\":[]"))
    }
}
