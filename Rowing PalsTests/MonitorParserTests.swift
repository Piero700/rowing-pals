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
}
