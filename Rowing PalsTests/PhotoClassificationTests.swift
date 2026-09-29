//
//  PhotoClassificationTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
import UIKit
@testable import Rowing_Pals

/// Decisions 8–12 (docs/design/v2-decisions.md): added photos are sorted into
/// monitor pieces or environment photos automatically, wrong guesses can be
/// corrected, the most intense piece leads the post, and only a real new best
/// counts as a PB.
struct PhotoClassificationTests {
    private static let twoK = StandardTest.all.first { $0.key == "2k" }!
    private static let thirtyMin = StandardTest.all.first { $0.key == "30min" }!

    private static func field<T>(_ value: T?) -> MonitorField<T> {
        MonitorField(value: value, confidence: value == nil ? 0 : 1)
    }

    private static func fields(time: Int?, distance: Int?, split: Int?, rate: Double?) -> ParsedMonitorFields {
        ParsedMonitorFields(elapsedTimeMs: field(time), distanceM: field(distance), splitMs: field(split), rate: field(rate))
    }

    private static func piece(_ label: SegmentLabel, distanceM: Int, timeMs: Int) -> DraftSegment {
        DraftSegment(label: label, photoJPEG: Data([0]), fields: fields(time: timeMs, distance: distanceM, split: nil, rate: 20))
    }

    // MARK: Monitor detection

    @Test func nothingReadMeansEnvironmentPhoto() {
        #expect(!Self.fields(time: nil, distance: nil, split: nil, rate: nil).looksLikeMonitor)
    }

    @Test func oneReadingIsNotEnough() {
        #expect(!Self.fields(time: 420_000, distance: nil, split: nil, rate: nil).looksLikeMonitor)
    }

    @Test func twoReadingsMeanMonitor() {
        #expect(Self.fields(time: 420_000, distance: 2000, split: nil, rate: nil).looksLikeMonitor)
    }

    /// The real pipeline on the real monitor photos in docs/ocr-samples: every
    /// photo the parser can read must count as a monitor photo.
    @Test func realMonitorSamplesAreDetected() async throws {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/ocr-samples")
        let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
        #expect(!urls.isEmpty)
        var detected = 0
        for url in urls {
            guard let image = UIImage(contentsOfFile: url.path) else { continue }
            let parsed = MonitorParser.parse(try await OCRService.recognizeText(in: image))
            if parsed.looksLikeMonitor { detected += 1 }
        }
        print("Monitor photos detected: \(detected) of \(urls.count)")
        #expect(detected > 0)
    }

    // MARK: Corrections

    @Test func pieceCanBeMovedToPhotosAndBack() {
        let vm = ReviewSheetViewModel(selfieJPEG: Data([0]))
        vm.segments = [Self.piece(.main, distanceM: 5000, timeMs: 1_200_000),
                       Self.piece(.extra, distanceM: 2000, timeMs: 480_000)]
        let extraID = vm.segments[1].id
        vm.moveSegmentToGallery(extraID)
        #expect(vm.segments.count == 1)
        #expect(vm.galleryPhotos.count == 1)
        #expect(vm.totalDistanceM == 5000)

        vm.readGalleryPhotoAsMonitor(vm.galleryPhotos[0].id)
        #expect(vm.galleryPhotos.isEmpty)
        #expect(vm.segments.count == 2)
        #expect(vm.segments[1].label == .extra)
        // Numbers survive the round trip.
        #expect(vm.segments[1].distanceM == 2000)
        #expect(vm.segments[1].timeMs == 480_000)
        #expect(vm.totalDistanceM == 7000)
    }

    @Test func environmentPhotosAreCapped() {
        let vm = ReviewSheetViewModel(selfieJPEG: Data([0]))
        for i in 0..<ReviewSheetViewModel.maxGalleryPhotos { vm.addGalleryPhoto(Data([UInt8(i)])) }
        vm.segments = [Self.piece(.main, distanceM: 5000, timeMs: 1_200_000),
                       Self.piece(.extra, distanceM: 2000, timeMs: 480_000)]
        vm.moveSegmentToGallery(vm.segments[1].id)
        // Full gallery: the piece stays rather than being silently dropped.
        #expect(vm.segments.count == 2)
    }

    // MARK: Lead piece

    @Test func fastestNonWarmupPieceLeads() {
        let warmup = Self.piece(.warmup, distanceM: 1000, timeMs: 180_000)   // 1:30 — fastest, but a warm-up
        let steady = Self.piece(.main, distanceM: 10_000, timeMs: 2_700_000) // 2:15
        let hard = Self.piece(.extra, distanceM: 2000, timeMs: 420_000)      // 1:45
        let lead = ReviewSheetViewModel.leadSegmentID(in: [warmup, steady, hard], isTest: false)
        #expect(lead == hard.id)
    }

    @Test func aTestIsLedByTheMainPiece() {
        let main = Self.piece(.main, distanceM: 2000, timeMs: 420_000)
        let faster = Self.piece(.extra, distanceM: 500, timeMs: 95_000)
        #expect(ReviewSheetViewModel.leadSegmentID(in: [main, faster], isTest: true) == main.id)
    }

    @Test func onlyWarmupsFallBackToMainThenFirst() {
        let warmup = Self.piece(.warmup, distanceM: 1000, timeMs: 180_000)
        let cooldown = Self.piece(.cooldown, distanceM: 1000, timeMs: 200_000)
        #expect(ReviewSheetViewModel.leadSegmentID(in: [warmup, cooldown], isTest: false) == warmup.id)
        #expect(ReviewSheetViewModel.leadSegmentID(in: [], isTest: false) == nil)
    }

    // MARK: New PB

    @Test func fasterTwoKIsANewBest() {
        let previous = [(distanceM: 2000, timeMs: 430_000), (distanceM: 2000, timeMs: 425_000)]
        #expect(ReviewSheetViewModel.isNewBest(test: Self.twoK, distanceM: 2000, timeMs: 424_900, previous: previous))
        #expect(!ReviewSheetViewModel.isNewBest(test: Self.twoK, distanceM: 2000, timeMs: 425_000, previous: previous))
    }

    @Test func furtherThirtyMinutesIsANewBest() {
        let previous = [(distanceM: 7800, timeMs: 1_800_000)]
        #expect(ReviewSheetViewModel.isNewBest(test: Self.thirtyMin, distanceM: 7801, timeMs: 1_800_000, previous: previous))
        #expect(!ReviewSheetViewModel.isNewBest(test: Self.thirtyMin, distanceM: 7800, timeMs: 1_799_000, previous: previous))
    }

    @Test func firstEverResultCounts() {
        #expect(ReviewSheetViewModel.isNewBest(test: Self.twoK, distanceM: 2000, timeMs: 500_000, previous: []))
    }
}
