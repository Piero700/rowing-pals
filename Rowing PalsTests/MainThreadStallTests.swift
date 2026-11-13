//
//  MainThreadStallTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
import UIKit
@testable import Rowing_Pals

/// Reading a monitor photo and shrinking a camera photo are heavy (Vision's accurate text
/// recognition takes most of a second). Both are started from the main actor, so this checks the
/// work itself runs elsewhere: a heartbeat ticks on the main actor every few milliseconds while the
/// work runs, and the longest gap between ticks is how long the screen would have frozen.
@MainActor
@Suite(.serialized)
struct MainThreadStallTests {
    /// Longer than this between heartbeats and the user would see a hitch.
    private static let allowedStall: Duration = .milliseconds(100)

    private static var samplePhoto: URL {
        OCRRegressionFixture.samplesURL.appendingPathComponent("IMG_0593.jpeg")
    }

    @Test func readingAMonitorPhotoLeavesTheMainThreadFree() async throws {
        let image = try #require(UIImage(contentsOfFile: Self.samplePhoto.path))
        let (stall, took) = await Self.longestMainStall {
            _ = try? await OCRService.recognizeText(in: image)
        }
        print("PERF OCR first read: took \(took), longest main-thread stall \(stall)")
        let (again, tookAgain) = await Self.longestMainStall {
            _ = try? await OCRService.recognizeText(in: image)
        }
        print("PERF OCR second read: took \(tookAgain), longest main-thread stall \(again)")
        #expect(again < Self.allowedStall)
    }

    @Test func shrinkingACameraPhotoLeavesTheMainThreadFree() async throws {
        let data = try Data(contentsOf: Self.samplePhoto)
        // Before: the same steps the shutter used to run on the main actor.
        let (before, _) = await Self.longestMainStall {
            guard let image = UIImage(data: data) else { return }
            let scale = min(1, 1600 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            _ = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }.jpegData(compressionQuality: 0.7)
        }
        let (stall, took) = await Self.longestMainStall {
            _ = await PhotoDownscaler.jpeg(from: data, maxPixelSide: 1600, quality: 0.7)
        }
        print("PERF Downscale 12 MP: main-actor version stalled \(before); now took \(took), longest stall \(stall)")
        #expect(stall < Self.allowedStall)
    }

    @Test func shrinkingKeepsTheSizeAndOrientation() async throws {
        let data = try Data(contentsOf: Self.samplePhoto)
        let original = try #require(UIImage(data: data))
        let jpeg = try #require(await PhotoDownscaler.jpeg(from: data, maxPixelSide: 1600, quality: 0.7))
        let shrunk = try #require(UIImage(data: jpeg))
        let scale = 1600 / max(original.size.width, original.size.height)
        #expect(abs(shrunk.size.width - original.size.width * scale) <= 1)
        #expect(abs(shrunk.size.height - original.size.height * scale) <= 1)
        #expect(shrunk.imageOrientation == .up)
        // A photo already within the cap is re-encoded, not redrawn, when asked.
        let small = try #require(await PhotoDownscaler.jpeg(from: jpeg, maxPixelSide: 4000, quality: 0.8,
                                                            screenFormat: true, reencodesSmallPhotos: true))
        #expect(UIImage(data: small)?.size == shrunk.size)
    }

    /// Runs `work` on the main actor (as the Review screen does) while a main-actor heartbeat
    /// ticks every 5 ms; returns the longest gap between ticks and how long the work took.
    static func longestMainStall(_ work: @MainActor () async -> Void) async -> (stall: Duration, took: Duration) {
        let beat = Heartbeat()
        let ticking = Task { await beat.run() }
        try? await Task.sleep(for: .milliseconds(30))
        let start = ContinuousClock.now
        await work()
        let took = ContinuousClock.now - start
        beat.isRunning = false
        await ticking.value
        return (beat.longest, took)
    }

    @MainActor
    final class Heartbeat {
        var isRunning = true
        private(set) var longest: Duration = .zero

        func run() async {
            var last = ContinuousClock.now
            while isRunning {
                try? await Task.sleep(for: .milliseconds(5))
                let now = ContinuousClock.now
                longest = max(longest, now - last)
                last = now
            }
        }
    }
}
