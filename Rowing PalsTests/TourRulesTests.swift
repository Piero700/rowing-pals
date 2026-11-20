//
//  TourRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The first-run tour (decision 109): which cards, in what order, and when it starts by itself.
struct TourRulesTests {
    @Test func rowerTourCoversTheMainPartsInBarOrder() {
        let targets = TourRules.rowerSteps().map(\.target)
        #expect(targets == [.tab("Feed"), .newButton, .tab("Rankings"), .tab("Calendar"), .tab("Profile")])
    }

    @Test func noLogCardWithoutALogButton() {
        let targets = TourRules.rowerSteps(showsLog: false).map(\.target)
        #expect(!targets.contains(.newButton))
        #expect(targets.count == 4)
    }

    @Test func coachTourCoversItsTabsAndPlus() {
        let targets = TourRules.coachSteps.map(\.target)
        #expect(targets == [.tab("Rowers"), .tab("Workouts"), .tab("Boats"), .tab("Calendar"), .newButton])
        #expect(TourRules.steps(for: .coaching) == TourRules.coachSteps)
    }

    @Test func startsByItselfOnlyWhenUnseenAndHelperTextIsOn() {
        #expect(TourRules.startsByItself(seen: false, showsGuidance: true))
        #expect(!TourRules.startsByItself(seen: true, showsGuidance: true))
        #expect(!TourRules.startsByItself(seen: false, showsGuidance: false))
    }

    @Test func eachVersionRemembersItsOwnTour() {
        #expect(TourRules.seenKey(.rowing) != TourRules.seenKey(.coaching))
    }

    @Test func cardsAreShortAndInUKEnglish() {
        for step in TourRules.rowerSteps() + TourRules.coachSteps {
            #expect(step.body.count <= 160, "\(step.title) is long for a tour card")
            #expect(!step.body.lowercased().contains("meter"))
            #expect(!step.body.lowercased().contains("pace"))
        }
        #expect(TourRules.progressText(index: 1, count: 5) == "2 of 5")
    }

    /// Replay is its own counter: clearing "seen" did nothing for someone who'd never seen the tour.
    @Test func replayHasItsOwnKey() {
        #expect(TourRules.replayKey != TourRules.seenKey(.rowing))
        #expect(TourRules.replayKey != TourRules.seenKey(.coaching))
    }
}
