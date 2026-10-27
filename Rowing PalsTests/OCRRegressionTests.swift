//
//  OCRRegressionTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
import UIKit
@testable import Rowing_Pals

/// The OCR regression test: runs the real pipeline the Review screen uses (`OCRService` then
/// `MonitorParser`) over every photo in docs/ocr-samples/ and compares each field with the
/// readout written down in docs/ocr-samples/expected-readouts.json. One test case per photo, one
/// issue per wrong field, so a failure reads "IMG_0593.jpeg — split: expected 1:49.5 …, read …".
///
/// Fields the pipeline already got wrong on 2026-10-27 are listed per photo under
/// `baselineFailures` and show as known issues, so the suite stays green until something that
/// used to read correctly stops doing so. Results and how to rerun:
/// docs/testing/ocr-regression-2026-10-27.md.
@Suite(.serialized)
struct OCRRegressionTests {
    private static let sampleImageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]

    @Test func everySamplePhotoHasExpectedValues() throws {
        let fixtures = OCRRegressionFixture.all
        try #require(!fixtures.isEmpty, "docs/ocr-samples/expected-readouts.json is missing, empty or not valid JSON for OCRRegressionFixture.")

        let photos = try FileManager.default
            .contentsOfDirectory(at: OCRRegressionFixture.samplesURL, includingPropertiesForKeys: nil)
            .filter { Self.sampleImageExtensions.contains($0.pathExtension.lowercased()) }
            .map(\.lastPathComponent)
        let described = Set(fixtures.map(\.file))

        for photo in photos.sorted() where !described.contains(photo) {
            Issue.record("\(photo) is in docs/ocr-samples/ but has no entry in expected-readouts.json — add what the monitor shows.")
        }
        for fixture in fixtures where !photos.contains(fixture.file) {
            Issue.record("expected-readouts.json describes \(fixture.file), which isn't in docs/ocr-samples/.")
        }
    }

    @Test(arguments: OCRRegressionFixture.all)
    func readsTheSummaryRow(of fixture: OCRRegressionFixture) async throws {
        let image = try #require(UIImage(contentsOfFile: fixture.imageURL.path), "\(fixture.file): couldn't load the photo.")
        let fields = MonitorParser.parse(try await OCRService.recognizeText(in: image))
        let expected = fixture.expected

        compare("elapsedTimeMs", "time", expected.elapsedTimeMs, fields.elapsedTimeMs.value, in: fixture, show: Self.duration)
        compare("distanceM", "distance", expected.distanceM, fields.distanceM.value, in: fixture) { "\($0) m" }
        compare("splitMs", "split", expected.splitMs, fields.splitMs.value, in: fixture, show: Self.duration)
        compare("rate", "rate", expected.rate, fields.rate.value, in: fixture) { "\(Int($0)) s/m" }
        // Int? against Int?: "no rep distance" is a value here, so a nil read matches a nil expectation.
        compare("repDistanceM", "rep distance", expected.repDistanceM, fields.repDistanceM, in: fixture) { value in
            value.map { "\($0) m" } ?? "none"
        }
    }

    /// Records one issue if `actual` differs from `expected` (nil `actual` = nothing read): a
    /// known issue when the field is in the photo's baseline, a failure otherwise. A baseline
    /// field that now reads correctly is reported too, so the baseline gets tightened rather than
    /// going stale.
    private func compare<Value: Equatable>(
        _ key: String,
        _ label: String,
        _ expected: Value,
        _ actual: Value?,
        in fixture: OCRRegressionFixture,
        show: (Value) -> String
    ) {
        let isBaseline = fixture.baselineFailures.contains(key)
        guard actual != expected else {
            if isBaseline {
                Issue.record("\(fixture.file) — \(label) now reads correctly (\(show(expected))). Remove \"\(key)\" from its baselineFailures in expected-readouts.json.")
            }
            return
        }

        let read = actual.map(show) ?? "nothing"
        let doubt = fixture.uncertain.contains(key) ? " [expected value marked uncertain — check the photo]" : ""
        let message = Comment(rawValue: "\(fixture.file) — \(label): expected \(show(expected)), read \(read)\(doubt)")
        if isBaseline {
            withKnownIssue { Issue.record(message) }
        } else {
            Issue.record(message)
        }
    }

    /// 79_000 → "1:19.0 (79000 ms)"; 3_603_700 → "1:00:03.7 (3603700 ms)".
    private static func duration(_ ms: Int) -> String {
        let tenths = ms / 100
        let seconds = tenths / 10
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        let clock = hours > 0
            ? String(format: "%d:%02d:%02d.%d", hours, minutes, secs, tenths % 10)
            : String(format: "%d:%02d.%d", minutes, secs, tenths % 10)
        return "\(clock) (\(ms) ms)"
    }
}
