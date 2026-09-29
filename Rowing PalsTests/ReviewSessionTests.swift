//
//  ReviewSessionTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Redesign phase F: session-type validation, the derived average, the
/// always-required stroke-rate confirmation, and what a manual entry is
/// allowed to do (docs/design/v2-decisions.md; manual sessions stay personal).
struct ReviewSessionTests {
    private static let twoK = StandardTest.all.first { $0.key == "2k" }!
    private static let thirtyMin = StandardTest.all.first { $0.key == "30min" }!

    /// A photographed piece with every field read at full confidence.
    private static func photographedSegment(
        distanceM: Int, timeMs: Int, rate: Double, label: SegmentLabel = .main
    ) -> DraftSegment {
        let fields = ParsedMonitorFields(
            elapsedTimeMs: MonitorField(value: timeMs, confidence: 1),
            distanceM: MonitorField(value: distanceM, confidence: 1),
            splitMs: MonitorField(value: 999_999, confidence: 1),
            rate: MonitorField(value: rate, confidence: 1)
        )
        return DraftSegment(label: label, photoJPEG: Data([0]), fields: fields)
    }

    // MARK: StandardTest.accepts

    @Test func distanceTestNeedsExactDistance() {
        #expect(Self.twoK.accepts(distanceM: 2000, timeMs: 420_000))
        #expect(!Self.twoK.accepts(distanceM: 1999, timeMs: 420_000))
        #expect(!Self.twoK.accepts(distanceM: 2001, timeMs: 420_000))
    }

    @Test func timedTestAllowsSmallFinishTolerance() {
        let thirty = 30 * 60 * 1000
        #expect(Self.thirtyMin.accepts(distanceM: 8000, timeMs: thirty))
        #expect(Self.thirtyMin.accepts(distanceM: 8000, timeMs: thirty + 1500))
        #expect(!Self.thirtyMin.accepts(distanceM: 8000, timeMs: thirty + 60_000))
    }

    // MARK: SessionKind

    @Test func trainingHasNoProblem() {
        #expect(SessionKind.training.problem(distanceM: 1234, timeMs: 5678) == nil)
    }

    @Test func testKindExplainsAMismatch() {
        let kind = SessionKind.test(Self.twoK)
        #expect(kind.problem(distanceM: 2000, timeMs: 420_000) == nil)
        #expect(kind.problem(distanceM: 1800, timeMs: 420_000) != nil)
    }

    @Test func dropdownOffersTrainingThenEveryStandardTest() {
        let kinds = SessionKind.allCases
        #expect(kinds.first == .training)
        #expect(kinds.count == StandardTest.all.count + 1)
    }

    @Test func testKindStoresItsOwnLabel() {
        #expect(SessionKind.test(Self.twoK).testLabel == "2k test")
        #expect(SessionKind.training.testLabel == nil)
    }

    // MARK: Derived average

    @Test func averageIsDerivedFromDistanceAndTimeNotTheMonitor() {
        // 2000 m in 7:00.0 → 105 s per 500 m, whatever split the monitor showed.
        let segment = Self.photographedSegment(distanceM: 2000, timeMs: 420_000, rate: 24)
        #expect(segment.splitMs == 105_000)
    }

    @Test func averageUpdatesWhenDistanceOrTimeChange() {
        var segment = Self.photographedSegment(distanceM: 2000, timeMs: 420_000, rate: 24)
        segment.timeMs = 400_000
        segment.recomputeSplit()
        #expect(segment.splitMs == 100_000)
    }

    @Test func averageIsZeroUntilBothAreKnown() {
        var segment = DraftSegment(manualLabel: .main)
        segment.distanceM = 2000
        segment.recomputeSplit()
        #expect(segment.splitMs == 0)
    }

    // MARK: Stroke-rate confirmation

    @Test func photographedPieceMustBeConfirmedBeforePosting() {
        let vm = ReviewSheetViewModel(selfieJPEG: Data([0]))
        vm.segments = [Self.photographedSegment(distanceM: 2000, timeMs: 420_000, rate: 24)]
        #expect(vm.postBlocker == "Confirm the stroke rate before posting.")
        #expect(!vm.canPost)

        vm.segments[0].isRateConfirmed = true
        #expect(vm.postBlocker == nil)
        #expect(vm.canPost)
    }

    // MARK: Session type on a photographed session

    @Test func choosingATestBlocksPostingWhenTheDistanceDoesNotMatch() {
        let vm = ReviewSheetViewModel(selfieJPEG: Data([0]))
        vm.segments = [Self.photographedSegment(distanceM: 1800, timeMs: 420_000, rate: 24)]
        vm.segments[0].isRateConfirmed = true
        vm.sessionKind = .test(Self.twoK)
        #expect(vm.sessionKindProblem != nil)
        #expect(!vm.canPost)

        vm.sessionKind = .training
        #expect(vm.canPost)
    }

    @Test func aTestNeedsAMainPiece() {
        let vm = ReviewSheetViewModel(selfieJPEG: Data([0]))
        vm.segments = [Self.photographedSegment(distanceM: 2000, timeMs: 420_000, rate: 24, label: .extra)]
        vm.segments[0].isRateConfirmed = true
        vm.sessionKind = .test(Self.twoK)
        #expect(vm.sessionKindProblem != nil)
    }

    @Test func aMatchingMainPieceOnlySuggestsATest() {
        let vm = ReviewSheetViewModel(selfieJPEG: Data([0]))
        vm.segments = [Self.photographedSegment(distanceM: 2000, timeMs: 420_000, rate: 24)]
        #expect(vm.detectedTest?.key == "2k")
        #expect(vm.showsTestPrompt)
        // Nothing enters the rankings until the rower says yes.
        #expect(vm.sessionKind == .training)

        vm.decideTest(accepted: true)
        #expect(vm.sessionKind == .test(Self.twoK))
        #expect(!vm.showsTestPrompt)
    }

    @Test func decliningTheSuggestionHidesItAndStaysTraining() {
        let vm = ReviewSheetViewModel(selfieJPEG: Data([0]))
        vm.segments = [Self.photographedSegment(distanceM: 2000, timeMs: 420_000, rate: 24)]
        vm.decideTest(accepted: false)
        #expect(vm.sessionKind == .training)
        #expect(!vm.showsTestPrompt)
    }

    // MARK: Manual entry

    @Test func manualEntryStartsWithOneBlankConfirmedPiece() {
        let vm = ReviewSheetViewModel(selfieJPEG: nil)
        #expect(vm.isManual)
        #expect(vm.segments.count == 1)
        #expect(vm.segments[0].isManual)
        #expect(!vm.hasUnconfirmedRate)
    }

    @Test func manualEntryCannotBePostedBlank() {
        let vm = ReviewSheetViewModel(selfieJPEG: nil)
        #expect(vm.postBlocker == "Enter a distance and time for every piece.")
        #expect(!vm.canPost)
    }

    @Test func manualEntryNeedsAStrokeRate() {
        let vm = ReviewSheetViewModel(selfieJPEG: nil)
        vm.segments[0].distanceM = 5000
        vm.segments[0].timeMs = 1_200_000
        #expect(vm.postBlocker == "Enter the stroke rate for every piece.")
        vm.segments[0].rate = 20
        #expect(vm.canPost)
    }

    @Test func manualEntryIsTrainingOnlyAndNeverSuggestsATest() {
        let vm = ReviewSheetViewModel(selfieJPEG: nil)
        vm.segments[0].distanceM = 2000
        vm.segments[0].timeMs = 420_000
        vm.segments[0].rate = 24
        #expect(vm.availableKinds == [.training])
        #expect(vm.detectedTest == nil)
        #expect(!vm.showsTestPrompt)
    }

    @Test func removingAPieceLeavesTheOthers() {
        let vm = ReviewSheetViewModel(selfieJPEG: nil)
        vm.addManualSegment()
        #expect(vm.segments.count == 2)
        vm.removeSegment(vm.segments[1].id)
        #expect(vm.segments.count == 1)
    }

    // MARK: Extra photos

    @Test func extraPhotosCanBeAddedAndRemoved() {
        let vm = ReviewSheetViewModel(selfieJPEG: Data([0]))
        vm.addGalleryPhoto(Data([1]))
        vm.addGalleryPhoto(Data([2]))
        #expect(vm.galleryPhotos.count == 2)
        vm.removeGalleryPhoto(vm.galleryPhotos[0].id)
        #expect(vm.galleryPhotos.map(\.jpeg) == [Data([2])])
    }
}
