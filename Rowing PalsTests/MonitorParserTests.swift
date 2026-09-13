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

    @Test func parsesSampleMonitorPhotos() async throws {
        let samplesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MonitorParserTests.swift
            .deletingLastPathComponent() // Rowing PalsTests/
            .appendingPathComponent("docs/ocr-samples")

        let imageURLs = ((try? FileManager.default.contentsOfDirectory(
            at: samplesURL,
            includingPropertiesForKeys: nil
        )) ?? [])
            .filter { Self.sampleImageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !imageURLs.isEmpty else {
            print("No sample images in docs/ocr-samples/ yet — see its README. Nothing to verify until real PM5 photos are added.")
            return
        }

        var allFourCount = 0
        for url in imageURLs {
            guard let image = UIImage(contentsOfFile: url.path) else {
                print("\(url.lastPathComponent): couldn't load as an image")
                continue
            }

            let observations = try await OCRService.recognizeText(in: image)
            let fields = MonitorParser.parse(observations)

            print("""
            \(url.lastPathComponent):
              time:     \(describe(fields.elapsedTimeMs))
              distance: \(describe(fields.distanceM))
              split:    \(describe(fields.splitMs))
              rate:     \(describe(fields.rate))
            """)

            if fields.hasAllFields { allFourCount += 1 }
        }

        let percentage = Double(allFourCount) / Double(imageURLs.count) * 100
        print("\n\(allFourCount)/\(imageURLs.count) images (\(String(format: "%.0f", percentage))%) produced all four fields.")

        #expect(!imageURLs.isEmpty, "Add real PM5 photos to docs/ocr-samples/ to actually exercise the parser.")
    }

    private func describe<Value>(_ field: MonitorField<Value>) -> String {
        guard let value = field.value else { return "— (no reading)" }
        return "\(value) (confidence \(String(format: "%.2f", field.confidence)))"
    }
}
