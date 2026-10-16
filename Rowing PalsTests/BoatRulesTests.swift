//
//  BoatRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// How boats are laid out (decision 67) and how a saved boat is checked (decision 70).
struct BoatRulesTests {
    @Test func aStrokeRiggedFourAlternatesFromStroke() {
        // Seat 4 (stroke) on stroke side, then alternating: B bow side, 2 stroke, 3 bow, S stroke.
        let sides = (1...4).map { BoatRules.side(ofSeat: $0, type: .four, rigging: .stroke) }
        #expect(sides == [.bow, .stroke, .bow, .stroke])
    }

    @Test func bowRiggingSwapsEverySide() {
        let sides = (1...4).map { BoatRules.side(ofSeat: $0, type: .four, rigging: .bow) }
        #expect(sides == [.stroke, .bow, .stroke, .bow])
        #expect(BoatRules.side(ofSeat: 8, type: .eight, rigging: .stroke) == .stroke)
        #expect(BoatRules.side(ofSeat: 1, type: .eight, rigging: .stroke) == .bow)
    }

    @Test func scullsAndTheCoxHaveNoSide() {
        #expect(BoatRules.side(ofSeat: 1, type: .double, rigging: .stroke) == nil)
        #expect(BoatRules.side(ofSeat: 0, type: .eight, rigging: .stroke) == nil)
    }

    @Test func seatsRunBowToStrokeThenCox() {
        #expect(BoatRules.seats(.four) == [1, 2, 3, 4])
        #expect(BoatRules.seats(.coxedFour) == [1, 2, 3, 4, 0])
        #expect(BoatType.eight.crewSize == 9)
        #expect(BoatType.pair.label == "2\u{2212}")
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
}
