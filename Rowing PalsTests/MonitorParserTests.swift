//
//  MonitorParserTests.swift
//  Rowing PalsTests
//

import Testing
import UIKit
@testable import Rowing_Pals

/// Runs the real OCR + parsing pipeline over every image in
/// docs/ocr-samples/ and prints what it extracted, per task 09's verify
/// step. Reads directly from that folder on disk (not bundled as test
/// resources) so adding a photo there doesn't need an Xcode project change.
struct MonitorParserTests {
    private static let sampleImageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]

    private static var samplesURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MonitorParserTests.swift
            .deletingLastPathComponent() // Rowing PalsTests/
            .appendingPathComponent("docs/ocr-samples")
    }

    private static var sampleImageURLs: [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: samplesURL, includingPropertiesForKeys: nil)) ?? [])
            .filter { sampleImageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    @Test func parsesSampleMonitorPhotos() async throws {
        let imageURLs = Self.sampleImageURLs

        guard !imageURLs.isEmpty else {
            print("No sample images in docs/ocr-samples/ yet — see its README. Nothing to verify until real PM5 photos are added.")
            return
        }

        var allFourCount = 0
        var report = ""
        for url in imageURLs {
            guard let image = UIImage(contentsOfFile: url.path) else {
                report += "\(url.lastPathComponent): couldn't load as an image\n"
                continue
            }

            let observations = try await OCRService.recognizeText(in: image)
            let fields = MonitorParser.parse(observations)

            report += """
            \(url.lastPathComponent):
              time:     \(describe(fields.elapsedTimeMs))
              distance: \(describe(fields.distanceM))
              split:    \(describe(fields.splitMs))
              rate:     \(describe(fields.rate))

            """

            if fields.hasAllFields { allFourCount += 1 }
        }

        let percentage = Double(allFourCount) / Double(imageURLs.count) * 100
        report += "\n\(allFourCount)/\(imageURLs.count) images (\(String(format: "%.0f", percentage))%) produced all four fields.\n"

        // xcresulttool in this environment doesn't surface Swift Testing's
        // captured console output, so the report also goes to a file —
        // see MonitorParser.swift's doc comment for why this test exists.
        try? report.write(toFile: "/tmp/monitor_parser_report.txt", atomically: true, encoding: .utf8)
        print(report)

        #expect(!imageURLs.isEmpty, "Add real PM5 photos to docs/ocr-samples/ to actually exercise the parser.")
    }

    private func describe<Value>(_ field: MonitorField<Value>) -> String {
        guard let value = field.value else { return "— (no reading)" }
        return "\(value) (confidence \(String(format: "%.2f", field.confidence)))"
    }

    // MARK: - Damaged summary rows (IMG_0647)

    /// One Vision observation centred at (x, y), as OCRService returns them (y up).
    private static func observation(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat = 0.05) -> RecognizedTextObservation {
        RecognizedTextObservation(
            text: text,
            boundingBox: CGRect(x: x - width / 2, y: y - 0.005, width: width, height: 0.01),
            confidence: 1
        )
    }

    /// The View Detail table from IMG_0647 as the simulator's Vision reads it: header, then the
    /// summary row, then two clean 300 m split rows that give the column positions.
    private static func table(summary: [RecognizedTextObservation], title: String = "1500m") -> [RecognizedTextObservation] {
        [
            observation(title, x: 0.29, y: 0.645),
            observation("ume", x: 0.326, y: 0.611),
            observation("meter", x: 0.384, y: 0.611),
            observation("1500m", x: 0.449, y: 0.611),
        ] + summary + [
            observation("1:07.5", x: 0.318, y: 0.575),
            observation("300", x: 0.394, y: 0.575),
            observation("1:52.5", x: 0.451, y: 0.575),
            observation("20", x: 0.500, y: 0.575, width: 0.023),
            observation("1:05.5", x: 0.317, y: 0.558),
            observation("600", x: 0.394, y: 0.558),
            observation("1:49.1", x: 0.450, y: 0.558),
            observation("21", x: 0.499, y: 0.558, width: 0.025),
        ]
    }

    @Test func keepsTheOtherFieldsAndRecoversTheTimeWhenTheColonIsLost() {
        let fields = MonitorParser.parse(Self.table(summary: [
            Self.observation("5217", x: 0.317, y: 0.593),
            Self.observation("1500", x: 0.390, y: 0.594, width: 0.043),
            Self.observation("1:47.2 21", x: 0.466, y: 0.595, width: 0.087),
        ]))

        #expect(fields.distanceM.value == 1500)
        #expect(fields.splitMs.value == 107_200)
        #expect(fields.rate.value == 21)
        // 5217 → 5:21.7, which agrees with 1:47.2 × 3 = 5:21.6 within the monitor's truncation.
        #expect(fields.elapsedTimeMs.value == 321_700)
        #expect(fields.elapsedTimeMs.confidence < 0.5, "A rebuilt time must show as low confidence on Review.")
    }

    @Test func leavesTheTimeEmptyWhenTheDigitsDisagreeWithTheSplit() {
        // macOS Vision's reading of the same photo: the 7 misread as a 3 → 5:21.3, 0.3 s under
        // split × distance, which the monitor's truncated split can't produce.
        let fields = MonitorParser.parse(Self.table(summary: [
            Self.observation("5213", x: 0.317, y: 0.593),
            Self.observation("1500", x: 0.390, y: 0.594, width: 0.043),
            Self.observation("1:47.2 21", x: 0.466, y: 0.595, width: 0.087),
        ]))

        #expect(fields.elapsedTimeMs.value == nil)
        #expect(fields.distanceM.value == 1500)
        #expect(fields.splitMs.value == 107_200)
        #expect(fields.rate.value == 21)
    }

    @Test func separatesASplitAndRateReadWithNoSpaceBetween() {
        let fields = MonitorParser.parse(Self.table(summary: [
            Self.observation("5:21.7", x: 0.317, y: 0.593),
            Self.observation("1500", x: 0.390, y: 0.594, width: 0.043),
            Self.observation("1:47.221", x: 0.466, y: 0.595, width: 0.087),
        ]))

        #expect(fields.elapsedTimeMs.value == 321_700)
        #expect(fields.elapsedTimeMs.confidence == 1, "A cleanly read time keeps Vision's own confidence.")
        #expect(fields.distanceM.value == 1500)
        #expect(fields.splitMs.value == 107_200)
        #expect(fields.rate.value == 21)
    }

    @Test func mergedTokenSplittingNeverCutsARealDuration() {
        #expect(MonitorParser.splitMergedSplitAndRate("1:47.221") == ["1:47.2", "21"])
        #expect(MonitorParser.splitMergedSplitAndRate("1:47.2") == ["1:47.2"])
        #expect(MonitorParser.splitMergedSplitAndRate("34:40.1") == ["34:40.1"])
        #expect(MonitorParser.splitMergedSplitAndRate("1:00:03.7") == ["1:00:03.7"])
        #expect(MonitorParser.splitMergedSplitAndRate(":40.7") == [":40.7"])
    }

    @Test func recoversColonlessTimesOnlyInsideTheSplitWindow() {
        #expect(MonitorParser.recoveredTimeMs(fromDigits: "5217", splitMs: 107_200, distanceM: 1500) == 321_700)
        #expect(MonitorParser.recoveredTimeMs(fromDigits: "5213", splitMs: 107_200, distanceM: 1500) == nil)
        // IMG_0880: 1:00:03.7 over 13,050 m at 2:18.0.
        #expect(MonitorParser.recoveredTimeMs(fromDigits: "100037", splitMs: 138_000, distanceM: 13_050) == 3_603_700)
        // Seconds can't be 60 or more.
        #expect(MonitorParser.recoveredTimeMs(fromDigits: "5617", splitMs: 107_200, distanceM: 1500) == nil)
        // Too few digits to be M:SS.d, or letters mixed in: not a time that lost its colon.
        #expect(MonitorParser.recoveredTimeMs(fromDigits: "521", splitMs: 107_200, distanceM: 1500) == nil)
        #expect(MonitorParser.recoveredTimeMs(fromDigits: "52l7", splitMs: 107_200, distanceM: 1500) == nil)
    }

    // MARK: - Ambiguous interval titles (IMG_0897 / IMG_0898, PM3)

    @Test func readsARepDistanceWhenTheXWasReadAsAZero() {
        // The PM3's 20x500m table: total 10,000 m, per-rep rows of 500 m.
        let observations: [RecognizedTextObservation] = [
            Self.observation("200500m/:20r", x: 0.344, y: 0.625, width: 0.166),
            Self.observation("time meter", x: 0.400, y: 0.576, width: 0.145),
            Self.observation(",500m 5/m", x: 0.559, y: 0.584, width: 0.139),
            Self.observation("34:40.1", x: 0.340, y: 0.548),
            Self.observation("10000", x: 0.443, y: 0.552),
            Self.observation("1:44.0", x: 0.533, y: 0.555),
            Self.observation("29", x: 0.601, y: 0.557, width: 0.031),
            Self.observation("1:46.5", x: 0.351, y: 0.520),
            Self.observation("500", x: 0.455, y: 0.525),
            Self.observation("1:46.5", x: 0.534, y: 0.528),
            Self.observation("29", x: 0.603, y: 0.531, width: 0.031),
        ]
        let fields = MonitorParser.parse(observations)

        #expect(fields.repDistanceM == 500)
        #expect(fields.distanceM.value == 10_000)
    }

    @Test func ambiguousTitleNeedsTheTableToBackIt() {
        // Backed by the total (20 × 500 = 10,000) or by two per-rep rows.
        #expect(MonitorParser.repDistance(fromAmbiguousTitle: "200500m/:20r", totalDistanceM: 10_000, rowNumbers: []) == 500)
        #expect(MonitorParser.repDistance(fromAmbiguousTitle: "200500ml20г", totalDistanceM: nil, rowNumbers: [500, 29, 500, 30]) == 500)
        // 2x1000m with the x read as 0.
        #expect(MonitorParser.repDistance(fromAmbiguousTitle: "201000m/2:00r", totalDistanceM: 2000, rowNumbers: []) == 1000)
        // Nothing in the table agrees: no guess.
        #expect(MonitorParser.repDistance(fromAmbiguousTitle: "200500m/:20r", totalDistanceM: 6000, rowNumbers: [1500, 3000]) == nil)
        // Single pieces never split into a rep count and distance.
        #expect(MonitorParser.repDistance(fromAmbiguousTitle: "10000m", totalDistanceM: 10_000, rowNumbers: [2000, 4000]) == nil)
        #expect(MonitorParser.repDistance(fromAmbiguousTitle: "21097m", totalDistanceM: 21_097, rowNumbers: []) == nil)
    }
}
