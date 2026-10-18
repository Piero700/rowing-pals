//
//  BoatRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import SwiftUI
import Testing
@testable import Rowing_Pals

/// How boats are laid out (decision 67) and how a saved boat is checked (decision 70).
struct BoatRulesTests {
    @Test func aStrokeRiggedFourAlternatesFromStroke() {
        // Seat 4 (stroke) on stroke side, then alternating: B bow side, 2 stroke, 3 bow, S stroke.
        let four = BoatSetup(type: .four, rigging: .stroke)
        let sides = (1...4).map { BoatRules.side(ofSeat: $0, setup: four) }
        #expect(sides == [.bow, .stroke, .bow, .stroke])
        #expect(BoatRules.standardSides(.four, rigging: .stroke) == "BSBS")
    }

    @Test func bowRiggingSwapsEverySide() {
        let sides = (1...4).map { BoatRules.side(ofSeat: $0, setup: BoatSetup(type: .four, rigging: .bow)) }
        #expect(sides == [.stroke, .bow, .stroke, .bow])
        let eight = BoatSetup(type: .eight, rigging: .stroke)
        #expect(BoatRules.side(ofSeat: 8, setup: eight) == .stroke)
        #expect(BoatRules.side(ofSeat: 1, setup: eight) == .bow)
    }

    @Test func scullsAndTheCoxHaveNoSide() {
        #expect(BoatRules.side(ofSeat: 1, setup: BoatSetup(type: .double, rigging: .stroke)) == nil)
        #expect(BoatRules.side(ofSeat: 0, setup: BoatSetup(type: .eight, rigging: .stroke)) == nil)
    }

    @Test func seatsRunBowToStrokeThenCox() {
        #expect(BoatRules.seats(.four) == [1, 2, 3, 4])
        #expect(BoatRules.seats(.coxedFour) == [1, 2, 3, 4, 0])
        #expect(BoatType.eight.crewSize == 9)
        #expect(BoatType.pair.label == "2\u{2212}")
    }

    @Test func aCoxedQuadIsFourScullersAndACox() {
        let quad = BoatType.coxedQuad
        #expect(quad.label == "4x+")
        #expect(quad.isSculling && quad.isCoxed)
        #expect(quad.crewSize == 5)
        #expect(BoatRules.seats(quad) == [1, 2, 3, 4, 0])
        #expect(BoatRules.side(ofSeat: 2, setup: BoatSetup(type: quad, rigging: .stroke)) == nil)
        #expect(BoatRules.seatName(0, type: quad) == "Cox")
        #expect(BoatType.allCases.map(\.label) == ["1x", "2x", "2\u{2212}", "4\u{2212}", "4+", "4x", "4x+", "8+"])
    }

    @Test func seatsHaveTheirNames() {
        #expect(BoatRules.seatName(1, type: .four) == "Bow")
        #expect(BoatRules.seatName(4, type: .four) == "Stroke")
        #expect(BoatRules.seatName(0, type: .eight) == "Cox")
        #expect(BoatRules.seatMark(3, type: .eight) == "3")
        #expect(BoatRules.seatPhrase(4, type: .four) == "You’re at stroke in")
        #expect(BoatRules.seatPhrase(2, type: .four) == "You’re in seat 2 in")
        #expect(BoatRules.seatPhrase(0, type: .coxedFour) == "You’re coxing")
    }

    @Test func aRowerOnTheirOtherSideIsNoted() {
        #expect(BoatRules.offSideNote(.stroke, seatSide: .bow) == "Usually stroke side")
        #expect(BoatRules.offSideNote(.both, seatSide: .bow) == nil)
        #expect(BoatRules.offSideNote(.bow, seatSide: .bow) == nil)
        #expect(BoatRules.fits(.both, seatSide: .stroke))
        #expect(!BoatRules.fits(.bow, seatSide: .stroke))
    }

    @Test func aCoxSuitsTheCoxSeatAndIsTaggedElsewhere() {
        // Decision 78: coxes are Fits for the cox seat, everyone else isn't.
        #expect(BoatRules.suits(.cox, seat: 0, seatSide: nil))
        #expect(!BoatRules.suits(.both, seat: 0, seatSide: nil))
        #expect(!BoatRules.suits(.cox, seat: 2, seatSide: .stroke))
        #expect(BoatRules.suits(.stroke, seat: 2, seatSide: .stroke))
        // Sculling seats have no side, so nobody's marked.
        #expect(!BoatRules.suits(.both, seat: 2, seatSide: nil))
        // A cox placed in a rowing seat carries a Cox tag, never "Usually cox".
        #expect(BoatRules.seatNote(.cox, seat: 3, seatSide: .bow) == "Cox")
        #expect(BoatRules.seatNote(.cox, seat: 3, seatSide: nil) == "Cox")
        #expect(BoatRules.seatNote(.cox, seat: 0, seatSide: nil) == nil)
        #expect(BoatRules.offSideNote(.cox, seatSide: .bow) == nil)
        #expect(BoatRules.seatNote(.stroke, seat: 3, seatSide: .bow) == "Usually stroke side")
        #expect(RowingSide.allCases.map(\.label) == ["Stroke side", "Bow side", "Both", "Cox"])
    }

    @Test func theCrewLineGoesStrokeToBowThenCox() {
        let ids = (0..<5).map { _ in UUID() }
        let names = Dictionary(uniqueKeysWithValues: zip(ids, ["Marcus Reilly", "Joe Fenwick", "Tom Ashworth", "Piero Ciobanu", "Kate Simmons"]))
        let seats = [BoatSeat(seat: 1, userId: ids[0]), BoatSeat(seat: 2, userId: ids[1]), BoatSeat(seat: 3, userId: ids[2]),
                     BoatSeat(seat: 4, userId: ids[3]), BoatSeat(seat: 0, userId: ids[4])]
        #expect(BoatRules.crewLine(seats, names: names) == "Piero, Tom, Joe, Marcus · cox Kate")
    }

    @Test func aSavedBoatIsCheckedAgainstWhoCanGo() {
        let lucy = UUID(), tom = UUID()
        let names = [lucy: "Lucy Grant", tom: "Tom Ashworth"]
        let boat = SavedBoat(id: UUID(), name: "Pair", boatType: .pair, rigging: .stroke,
                             seats: [BoatSeat(seat: 1, userId: lucy), BoatSeat(seat: 2, userId: tom)])
        #expect(BoatRules.savedBoatCheck(boat, names: names, available: [lucy, tom], cant: [], seatedIn: [:]).text == "All 2 available")
        #expect(BoatRules.savedBoatCheck(boat, names: names, available: [tom], cant: [lucy], seatedIn: [:]).text
                == "Lucy can’t make it: swap them after adding")
        #expect(BoatRules.savedBoatCheck(boat, names: names, available: [lucy, tom], cant: [], seatedIn: [tom: "M1 four"]).text
                == "Tom is already in M1 four")
    }

    @Test func changingTheBoatTypeEmptiesSeatsItNoLongerHas() {
        let a = UUID(), b = UUID(), c = UUID()
        let seats = [BoatSeat(seat: 1, userId: a), BoatSeat(seat: 4, userId: b), BoatSeat(seat: 0, userId: c)]
        #expect(BoatRules.seats(seats, fittingInto: .pair).map(\.seat) == [1])
        #expect(BoatRules.seats(seats, fittingInto: .coxedFour).map(\.seat) == [1, 4, 0])
    }

    // MARK: - Custom rigging (decision 74) and boats on their side (decision 88)

    @Test func aBucketFourHasTheMiddlePairOnOneSide() {
        // Bow first: bow and stroke on stroke side, 2 and 3 on bow side.
        let bucket = BoatSetup(type: .four, rigging: .custom, sides: "SBBS")
        let sides = (1...4).map { BoatRules.side(ofSeat: $0, setup: bucket) }
        #expect(sides == [.stroke, .bow, .bow, .stroke])
    }

    @Test func flippingAnOarMakesTheRiggingCustom() {
        let four = BoatSetup(type: .four, rigging: .stroke)
        let flipped = BoatRules.flipping(1, in: four)
        #expect(flipped.rigging == .custom)
        #expect(flipped.sides == "SSBS")
        #expect(BoatRules.flipping(1, in: flipped).sides == "BSBS")
        // A sculling boat has no sides to flip.
        #expect(BoatRules.flipping(1, in: BoatSetup(type: .double, rigging: .stroke)) == BoatSetup(type: .double, rigging: .stroke))
    }

    @Test func onlyCustomRiggingKeepsSides() {
        #expect(BoatSetup(type: .four, rigging: .stroke, sides: "SBBS").sides == nil)
        #expect(BoatSetup(type: .four, rigging: .custom, sides: "SBBS").sides == "SBBS")
    }

    @Test func aBoatOnItsSideReadsCoxThenStrokeToBow() {
        #expect(BoatRules.seatsSternToBow(.coxedFour) == [0, 4, 3, 2, 1])
        #expect(BoatRules.seatsSternToBow(.double) == [2, 1])
        #expect(BoatRules.role(0, type: .coxedFour) == "Cox")
        #expect(BoatRules.role(4, type: .coxedFour) == "Stroke")
        #expect(BoatRules.role(1, type: .coxedFour) == "Bow")
        #expect(BoatRules.role(2, type: .coxedFour) == nil)
        #expect(BoatRules.role(1, type: .single) == nil)
        #expect(BoatRules.riggingLine(BoatSetup(type: .quad, rigging: .stroke)) == "Sculls")
        #expect(BoatRules.riggingLine(BoatSetup(type: .four, rigging: .custom, sides: "SBBS")) == "Custom")
    }

    // MARK: - Boat colours (decision 87)

    @Test func boatColoursAreKeptAsCapitalHex() {
        #expect(BoatPalette.normalised("#e5484d") == "#E5484D")
        #expect(BoatPalette.normalised("E5484D") == nil)
        #expect(BoatPalette.normalised("#12345") == nil)
        #expect(BoatPalette.normalised(nil) == nil)
        #expect(BoatPalette.name("#e5484d") == "Red")
        #expect(BoatPalette.name("#123456") == "Custom colour")
        #expect(BoatPalette.color("#ZZZZZZ") == nil)
        #expect(BoatPalette.hex(Color(hex: 0x30A46C)) == "#30A46C")
        #expect(Set(BoatPalette.swatches.map(\.hex)).count == BoatPalette.swatches.count)
    }
}
