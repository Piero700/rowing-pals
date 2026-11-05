//
//  NotepadScanTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
import UIKit
@testable import Rowing_Pals

/// Scanning a monitor for the coach notepad (decision 96, phase NP2): reading every interval row off
/// a photo (`MonitorParser.intervalRows`), joining several screens of one workout
/// (`NotepadRules.join` / `stitch`), and the scores a scan fills a rower's row with.
@MainActor
struct NotepadScanTests {
    // MARK: - Joining screens

    private static func row(_ split: String, rate: Int = 29, metres: Int = 500, number: Int? = nil) -> MonitorRow {
        let ms = milliseconds(split)
        return MonitorRow(timeMs: ms * metres / 500, distanceM: metres, splitMs: ms, rate: rate, number: number)
    }

    /// "1:48.3" → 108_300.
    private static func milliseconds(_ text: String) -> Int {
        let parts = text.split(separator: ":")
        let minutes = Int(parts[0]) ?? 0
        let seconds = Double(parts[1]) ?? 0
        return minutes * 60_000 + Int((seconds * 1000).rounded())
    }

    /// The 20 × 500m in docs/ocr-samples/ (IMG_0898-0899), as written down from the photos.
    private static let screen2 = ["1:48.3", "1:39.3", "1:48.3", "1:40.7", "1:48.2", "1:42.7", "1:48.5", "1:43.7"].map { row($0) }
    private static let screen3 = ["1:42.7", "1:48.5", "1:43.7", "1:48.3", "1:41.8", "1:47.5", "1:41.0"].map { row($0) }

    @Test func rowsOnBothScreensAreKeptOnce() {
        let joined = NotepadRules.join(Self.screen2, Self.screen3)
        #expect(joined.rows.count == 12)
        #expect(joined.overlap == 6...8)
        #expect(joined.newIndices == Set(8..<12))
        #expect(joined.rows.suffix(4).map(\.splitMs) == Self.screen3.suffix(4).map(\.splitMs))
    }

    @Test func screensThatDontOverlapFollowOn() {
        let first = ["1:46.5", "1:38.9", "1:46.2"].map { Self.row($0) }
        let joined = NotepadRules.join(first, Self.screen2)
        #expect(joined.rows.count == first.count + Self.screen2.count)
        #expect(joined.overlap == nil)
    }

    @Test func aSingleLookAlikeRowDoesntCountAsOverlap() {
        // The last row read and the next screen's first row share a split by chance, but differ in rate.
        let first = [Self.row("1:46.5"), Self.row("1:48.3", rate: 30)]
        let joined = NotepadRules.join(first, Self.screen2)
        #expect(joined.overlap == nil)
        #expect(joined.rows.count == 2 + Self.screen2.count)
    }

    @Test func aMisreadDigitInTheOverlapIsKeptOnceAndTheReadingThatAddsUpWins() {
        var misread = Self.screen3
        // "1:48.5" read as "1:43.5" for the split only: the time no longer matches it.
        misread[1].splitMs = Self.milliseconds("1:43.5")
        let joined = NotepadRules.join(Self.screen2, misread)
        #expect(joined.overlap == 6...8)
        #expect(joined.rows.count == 12)
        #expect(joined.rows[6].splitMs == Self.milliseconds("1:48.5"))

        // And the other way round: the earlier screen had the misread.
        var earlier = Self.screen2
        earlier[6].splitMs = Self.milliseconds("1:43.5")
        let fixed = NotepadRules.join(earlier, Self.screen3)
        #expect(fixed.rows.count == 12)
        #expect(fixed.rows[6].splitMs == Self.milliseconds("1:48.5"))
    }

    @Test func numberedRowsJoinByNumber() {
        let first = (1...8).map { Self.row("1:4\($0 % 10).0", number: $0) }
        let second = (6...12).map { Self.row("1:4\($0 % 10).0", number: $0) }
        let joined = NotepadRules.join(first, second)
        #expect(joined.rows.map(\.number) == Array(1...12))
        #expect(joined.overlap == 6...8)
        #expect(joined.newIndices == Set(8..<12))
    }

    @Test func theSummaryRowIsLeftOut() {
        var screen = Self.screen2
        screen.insert(MonitorRow(timeMs: 2_080_100, distanceM: 10_000, splitMs: 104_000, rate: 29, isSummary: true), at: 0)
        #expect(NotepadRules.join([], screen).rows == Self.screen2)
    }

    @Test func theSameScreenTwiceAddsNothing() {
        let joined = NotepadRules.join(Self.screen2, Self.screen2)
        #expect(joined.rows == Self.screen2)
        #expect(joined.newIndices.isEmpty)
    }

    // MARK: - Filling a row

    @Test func aScanFillsOneScorePerRepAndLeavesExtraRowsOff() {
        let workout = UUID(), rower = UUID()
        let scores = NotepadRules.scannedScores(rows: Self.screen2, summary: nil, repCount: 4, workoutId: workout, rowerId: rower)
        #expect(scores.map(\.pieceIndex) == [0, 1, 2, 3])
        #expect(scores.map(\.splitMs) == Self.screen2.prefix(4).map(\.splitMs))
        #expect(scores.allSatisfy { $0.source == .scanned && !$0.satOut && $0.rate == 29 && $0.distanceM == 500 })
    }

    @Test func aOnePieceWorkoutTakesTheSummaryRow() {
        let summary = MonitorRow(timeMs: 439_000, distanceM: 2000, splitMs: 109_700, rate: 24, isSummary: true)
        let scores = NotepadRules.scannedScores(rows: Self.screen2, summary: summary, repCount: 1, workoutId: UUID(), rowerId: UUID())
        #expect(scores.count == 1)
        #expect(scores.first?.splitMs == 109_700)
        #expect(scores.first?.timeMs == 439_000)
    }

    @Test func aRowWithoutASplitIsSkipped() {
        var rows = Self.screen2
        rows[1].splitMs = nil
        let scores = NotepadRules.scannedScores(rows: rows, summary: nil, repCount: 3, workoutId: UUID(), rowerId: UUID())
        #expect(scores.map(\.pieceIndex) == [0, 2])
    }

    // MARK: - Real photos

    /// The interval rows written down for each photo in expected-readouts.json.
    private struct Readouts: Decodable {
        struct Sample: Decodable {
            struct Intervals: Decodable {
                struct Row: Decodable {
                    let timeMs: Int
                    let distanceM: Int
                    let splitMs: Int
                    let rate: Int
                }
                let rows: [Row]
            }
            let file: String
            let intervals: Intervals
        }
        let samples: [Sample]
    }

    private static var readouts: [Readouts.Sample] {
        let url = OCRRegressionFixture.samplesURL.appendingPathComponent("expected-readouts.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Readouts.self, from: data) else { return [] }
        return decoded.samples.sorted { $0.file < $1.file }
    }

    private static func intervals(in file: String) async throws -> [MonitorRow] {
        let url = OCRRegressionFixture.samplesURL.appendingPathComponent(file)
        let image = try #require(UIImage(contentsOfFile: url.path), "\(file): couldn't load the photo.")
        return MonitorParser.intervalRows(try await OCRService.recognizeText(in: image))
    }

    /// Every sample photo, read row by row against what's written down for it. A reading that comes
    /// out **wrong** fails: it would put a false number on the page. A reading Vision didn't return
    /// at all (no rate on a row, say) is a known issue, not a failure — the box is left for the
    /// coach — and so is every row left out.
    @Test func readsTheIntervalRowsOffEverySamplePhoto() async throws {
        let samples = Self.readouts
        try #require(!samples.isEmpty, "expected-readouts.json is missing or has no interval rows.")
        for sample in samples {
            let read = try await Self.intervals(in: sample.file)
            let intervals = read.filter { !$0.isSummary }
            #expect(read.first?.isSummary == true, "\(sample.file): the first row should be the summary.")
            #expect(intervals.count <= sample.intervals.rows.count, "\(sample.file): read more interval rows than the screen has.")
            if intervals.count < sample.intervals.rows.count {
                withKnownIssue { Issue.record("\(sample.file): \(intervals.count) of \(sample.intervals.rows.count) interval rows read.") }
            }
            for (index, pair) in zip(intervals, sample.intervals.rows).enumerated() {
                let (row, expected) = pair
                let label = "\(sample.file) row \(index + 1)"
                Self.check(row.timeMs, expected.timeMs, "\(label) time")
                Self.check(row.distanceM, expected.distanceM, "\(label) metres")
                Self.check(row.splitMs, expected.splitMs, "\(label) split")
                Self.check(row.rate, expected.rate, "\(label) rate")
            }
        }
    }

    /// Fails on a wrong reading; a missing one is a known issue.
    private static func check(_ read: Int?, _ expected: Int, _ label: String) {
        guard let read else {
            withKnownIssue { Issue.record("\(label): not read (expected \(expected))") }
            return
        }
        #expect(read == expected, "\(label): read \(read), expected \(expected)")
    }

    /// The three photos of one 20 × 500m (reps 1-8, 9-16, 14-20) join into the 20 reps, in order.
    @Test func joinsTheThreeScreensOfThe20x500m() async throws {
        let screens = [
            try await Self.intervals(in: "IMG_0897.jpeg"),
            try await Self.intervals(in: "IMG_0898.jpeg"),
            try await Self.intervals(in: "IMG_0899.jpeg"),
        ]
        let byFile = Dictionary(uniqueKeysWithValues: Self.readouts.map { ($0.file, $0.intervals.rows) })
        let expected = (byFile["IMG_0897.jpeg"] ?? []) + (byFile["IMG_0898.jpeg"] ?? []) + (byFile["IMG_0899.jpeg"] ?? []).dropFirst(3)
        try #require(expected.count == 20)

        let joined = NotepadRules.stitch(screens)
        #expect(joined.count == 20)
        #expect(joined.map(\.splitMs) == expected.map { Optional($0.splitMs) })
        #expect(joined.map(\.rate) == expected.map { Optional($0.rate) })
    }
}
