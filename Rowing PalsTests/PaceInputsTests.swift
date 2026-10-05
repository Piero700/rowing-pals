//
//  PaceInputsTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
import PaceEngine
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

    /// HANDOFF.md phase 2: only zoned erg sessions' MAIN segments reach the engine — a 2k test
    /// with its warm-up and cool-down must not read as an all-out 6k.
    @Test func onlyMainSegmentsOfZonedSessionsFeedTheEngine() throws {
        let json = """
        [
          {"id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301", "session_date": "2026-10-01", "zone": "AN", "rpe": 9,
           "segments": [
             {"label": "warmup", "position": 0, "distance_m": 2000, "time_ms": 540000, "split_ms": 135000, "rate": 20, "rep_distance_m": null},
             {"label": "main", "position": 1, "distance_m": 2000, "time_ms": 420000, "split_ms": 105000, "rate": 32, "rep_distance_m": null},
             {"label": "cooldown", "position": 2, "distance_m": 2000, "time_ms": 600000, "split_ms": 150000, "rate": 18, "rep_distance_m": null}
           ]},
          {"id": "3F2504E0-4F89-11D3-9A0C-0305E82C3302", "session_date": "2026-10-02", "zone": null, "rpe": null,
           "segments": [
             {"label": "main", "position": 0, "distance_m": 10000, "time_ms": 2700000, "split_ms": 135000, "rate": 18, "rep_distance_m": null}
           ]},
          {"id": "3F2504E0-4F89-11D3-9A0C-0305E82C3303", "session_date": "2026-10-03", "zone": "TR", "rpe": null,
           "segments": [
             {"label": "main", "position": 2, "distance_m": 1000, "time_ms": 212000, "split_ms": null, "rate": null, "rep_distance_m": null},
             {"label": "main", "position": 0, "distance_m": 4000, "time_ms": 860000, "split_ms": null, "rate": null, "rep_distance_m": 500}
           ]}
        ]
        """
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let rows = try JSONDecoder().decode([PredictionService.SessionRow].self, from: Data(json.utf8))
        let history = PredictionService.history(from: rows, calendar: calendar)

        // The un-zoned session is left out; warm-up and cool-down never enter.
        #expect(history.count == 3)
        #expect(history[0].id == "3F2504E0-4F89-11D3-9A0C-0305E82C3301")
        #expect(history[0].distanceM == 2000)
        #expect(history[0].timeS == 420)
        #expect(history[0].tag == .an)
        #expect(history[0].rpe == 9)
        // Two main pieces in one session: in position order, the second with its own id.
        #expect(history[1].id == "3F2504E0-4F89-11D3-9A0C-0305E82C3303")
        #expect(history[1].repDistanceM == 500)
        #expect(history[2].id == "3F2504E0-4F89-11D3-9A0C-0305E82C3303-2")

        // And the engine takes it: the AN 2k is the closest-distance anchor for a 2k.
        let prediction = PacePredictor.predict(history: history, targetDistance: 2000,
                                               asOf: calendar.date(from: DateComponents(year: 2026, month: 10, day: 4))!,
                                               calendar: calendar)
        #expect(prediction.anchor?.sessionIds == ["3F2504E0-4F89-11D3-9A0C-0305E82C3301"])
        #expect(PredictionService.isShowable(prediction))
    }

    @Test func aPopulationEstimateIsNotShownYet() {
        // Decision 30: while the estimate is switched off, a cold-start estimate is "no prediction".
        let prediction = PacePredictor.predict(history: [], targetDistance: 2000, asOf: Date(),
                                               athlete: AthleteProfile(age: 27, sex: "male", weightKg: 82))
        #expect(prediction.confidenceScore == .populationEstimate)
        #expect(!PredictionService.isShowable(prediction))
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
