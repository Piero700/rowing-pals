//
//  PaceInputsTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// What the app collects for the Pace Engine (decisions 30–31): the rep distance read off an
/// interval workout's monitor title, the zone a test pre-selects, and the private weight field.
@MainActor
struct PaceInputsTests {
    @Test func repDistanceComesFromAnIntervalTitle() {
        #expect(MonitorParser.repDistance(fromTitle: "8x500m/1:00r") == 500)
        #expect(MonitorParser.repDistance(fromTitle: "View Detail 4x1000m/2:00r") == 1000)
        #expect(MonitorParser.repDistance(fromTitle: "3 x 2,000m/5:00r") == 2000)
        #expect(MonitorParser.repDistance(fromTitle: "5×1500m") == 1500)
    }

    @Test func noRepDistanceForSinglePiecesOrTimedReps() {
        #expect(MonitorParser.repDistance(fromTitle: "2000m") == nil)
        #expect(MonitorParser.repDistance(fromTitle: "14,000m Mar 10 2026") == nil)
        #expect(MonitorParser.repDistance(fromTitle: "8x2:00/1:00r") == nil)
        #expect(MonitorParser.repDistance(fromTitle: "1x2000m") == nil)
        #expect(MonitorParser.repDistance(fromTitle: "") == nil)
    }

    @Test func choosingATestPreselectsAllOut() {
        let viewModel = ReviewSheetViewModel(selfieJPEG: Data([0x01]))
        #expect(viewModel.zone == .ut2)
        viewModel.sessionKind = .test(StandardTest.all[2])
        #expect(viewModel.zone == .an)
        // The rower can still change it, and switching between tests doesn't reset it.
        viewModel.zone = .tr
        viewModel.sessionKind = .test(StandardTest.all[3])
        #expect(viewModel.zone == .tr)
    }

    @Test func weightMustBeAPlausibleNumber() {
        let settings = SettingsViewModel()
        settings.weightText = ""
        #expect(settings.weightProblem == nil)
        settings.weightText = "78,5"
        #expect(settings.weightProblem == nil)
        settings.weightText = "12"
        #expect(settings.weightProblem != nil)
        settings.weightText = "heavy"
        #expect(settings.weightProblem != nil)
        #expect(SettingsViewModel.weightString(80) == "80")
        #expect(SettingsViewModel.weightString(78.5) == "78.5")
    }
}
