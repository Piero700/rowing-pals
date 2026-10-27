//
//  OCRRegressionFixture.swift
//  Rowing PalsTests
//

import Foundation
import Testing

/// One monitor photo in docs/ocr-samples/ and what the OCR pipeline should read off it, from
/// docs/ocr-samples/expected-readouts.json. Read from disk next to the photos (like
/// `MonitorParserTests`), so adding a photo or fixing a value never needs an Xcode project change.
struct OCRRegressionFixture: Decodable, Sendable, CustomTestStringConvertible {
    /// The summary-row readout `MonitorParser.parse` should return.
    struct Expected: Decodable, Sendable {
        let elapsedTimeMs: Int
        let distanceM: Int
        let splitMs: Int
        let rate: Double
        let repDistanceM: Int?
    }

    let file: String
    let monitor: String
    let title: String
    let expected: Expected
    /// Field names whose expected value was read from the photo with some doubt and needs the
    /// user's check ("elapsedTimeMs", "distanceM", ...). Interval-row doubts live here too.
    let uncertain: [String]
    /// Fields the pipeline gets wrong today (the baseline, 2026-10-27). A mismatch on one of these
    /// is a known issue, not a failure; a mismatch anywhere else is a regression. Once a fix makes
    /// one of these right, the test says so, and the field comes off this list.
    let baselineFailures: [String]
    let notes: String

    var testDescription: String { "\(file) (\(title))" }

    static var samplesURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // OCRRegressionFixture.swift
            .deletingLastPathComponent() // Rowing PalsTests/
            .appendingPathComponent("docs/ocr-samples")
    }

    var imageURL: URL { Self.samplesURL.appendingPathComponent(file) }

    /// Every fixture, sorted by file name. Empty (and the test then fails on that) if the JSON is
    /// missing or malformed.
    static var all: [OCRRegressionFixture] {
        let url = samplesURL.appendingPathComponent("expected-readouts.json")
        guard let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(Document.self, from: data)
        else { return [] }
        return document.samples.sorted { $0.file < $1.file }
    }

    private struct Document: Decodable {
        let samples: [OCRRegressionFixture]
    }
}
