//
//  BoatRules.swift
//  Rowing Pals
//

import Foundation

/// How a boat is laid out (decision 67), kept free of the network so it can be tested. Seats are
/// numbered from bow: seat 1 is bow, the highest is stroke, 0 is the cox. In a stroke-rigged
/// sweep boat the stroke's oar is on stroke side and the seats alternate; bow-rigged is the
/// other way round. Sculling boats have no sides.
nonisolated enum BoatRules {
    /// Every seat from bow to stroke, then the cox's.
    static func seats(_ type: BoatType) -> [Int] {
        Array(1...type.rowers) + (type.isCoxed ? [0] : [])
    }

    /// Every seat from stern to bow, as a boat on its side reads left to right (decisions 82, 88):
    /// the cox, then stroke down to bow.
    static func seatsSternToBow(_ type: BoatType) -> [Int] {
        (type.isCoxed ? [0] : []) + Array((1...type.rowers).reversed())
    }

    /// The sides of a standard rig, bow first: "BSBS" for a stroke-rigged four.
    static func standardSides(_ type: BoatType, rigging: Rigging) -> String {
        String((1...type.rowers).map { seat -> Character in
            let sameParityAsStroke = (type.rowers - seat) % 2 == 0
            let strokeSide = rigging == .bow ? !sameParityAsStroke : sameParityAsStroke
            return strokeSide ? "S" : "B"
        })
    }

    /// The side a seat's oar is on; nil for a sculling boat or the cox.
    static func side(ofSeat seat: Int, setup: BoatSetup) -> RowingSide? {
        guard !setup.type.isSculling, seat > 0, seat <= setup.type.rowers else { return nil }
        let sides = setup.rigging == .custom
            ? (setup.sides ?? standardSides(setup.type, rigging: .stroke))
            : standardSides(setup.type, rigging: setup.rigging)
        let letters = Array(sides)
        guard seat - 1 < letters.count else { return nil }
        return letters[seat - 1] == "S" ? .stroke : .bow
    }

    /// The setup with one seat's oar on the other side: the boat becomes custom (decision 74).
    static func flipping(_ seat: Int, in setup: BoatSetup) -> BoatSetup {
        guard !setup.type.isSculling, seat > 0, seat <= setup.type.rowers else { return setup }
        var letters = Array(setup.rigging == .custom
            ? (setup.sides ?? standardSides(setup.type, rigging: .stroke))
            : standardSides(setup.type, rigging: setup.rigging))
        letters[seat - 1] = letters[seat - 1] == "S" ? "B" : "S"
        return BoatSetup(type: setup.type, rigging: .custom, sides: String(letters))
    }

    /// The line under a boat's name: "Stroke-rigged", "Custom", "Sculls".
    static func riggingLine(_ setup: BoatSetup) -> String {
        setup.type.isSculling ? "Sculls" : setup.rigging.label
    }

    /// "Bow", "2", "Stroke", "Cox"; a single's one seat is "Sculler".
    static func seatName(_ seat: Int, type: BoatType) -> String {
        if seat == 0 { return "Cox" }
        if type.rowers == 1 { return "Sculler" }
        if seat == type.rowers { return "Stroke" }
        if seat == 1 { return "Bow" }
        return "\(seat)"
    }

    /// The seat's mark in the drawing: "B", "2", "S", "C".
    static func seatMark(_ seat: Int, type: BoatType) -> String {
        if seat == 0 { return "C" }
        if type.rowers == 1 { return "1" }
        if seat == type.rowers { return "S" }
        if seat == 1 { return "B" }
        return "\(seat)"
    }

    /// "Cox", "Stroke", "Bow" under those seats of a boat on its side; nothing under the others
    /// (their number is in the seat) or in a single.
    static func role(_ seat: Int, type: BoatType) -> String? {
        if seat == 0 { return "Cox" }
        guard type.rowers > 1 else { return nil }
        if seat == type.rowers { return "Stroke" }
        if seat == 1 { return "Bow" }
        return nil
    }

    /// "Seat 2", "Stroke seat", "Bow seat", "Cox".
    static func seatTitle(_ seat: Int, type: BoatType) -> String {
        switch seatName(seat, type: type) {
        case "Cox": "Cox"
        case "Sculler": "Seat"
        case "Stroke": "Stroke seat"
        case "Bow": "Bow seat"
        default: "Seat \(seat)"
        }
    }

    /// "You’re at stroke in", "You’re in seat 2 in", "You’re coxing" (with the send-push alert).
    static func seatPhrase(_ seat: Int, type: BoatType) -> String {
        if seat == 0 { return "You’re coxing" }
        if type.rowers == 1 { return "You’re in" }
        if seat == type.rowers { return "You’re at stroke in" }
        if seat == 1 { return "You’re at bow in" }
        return "You’re in seat \(seat) in"
    }

    /// The Feed's boats (decision 79): today's whose session hasn't ended; once they're all over,
    /// tomorrow's. Nothing further ahead — the Calendar has those. Keeps the order given.
    static func feedBoats<Item>(_ items: [Item], session: (Item) -> WaterSession, now: Date, calendar: Calendar) -> [Item] {
        let unfinished = items.filter { session($0).endsAt > now }
        let today = unfinished.filter { calendar.isDate(session($0).startsAt, inSameDayAs: now) }
        if !today.isEmpty { return today }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return [] }
        return unfinished.filter { calendar.isDate(session($0).startsAt, inSameDayAs: tomorrow) }
    }

    /// Whether someone who rows `side` suits a seat on `seatSide` (either suits anyone who rows; a
    /// cox suits no rowing side, decision 78).
    static func fits(_ side: RowingSide?, seatSide: RowingSide?) -> Bool {
        if side == .cox { return false }
        guard let seatSide, let side else { return true }
        return side == .both || side == seatSide
    }

    /// Whether the picker marks someone **Fits** for `seat`: a cox for the cox seat (seat 0), and
    /// a rower on the seat's side for a sweep seat. Sculling seats mark nobody (decision 78).
    static func suits(_ side: RowingSide?, seat: Int, seatSide: RowingSide?) -> Bool {
        if seat == 0 { return side == .cox }
        guard seatSide != nil, side != nil else { return false }
        return fits(side, seatSide: seatSide)
    }

    /// "Usually stroke side" for someone seated on their other side; nil otherwise (and for a cox,
    /// who gets `seatNote`'s Cox tag instead).
    static func offSideNote(_ side: RowingSide?, seatSide: RowingSide?) -> String? {
        guard let side, let seatSide, side != .both, side != .cox, side != seatSide else { return nil }
        return "Usually \(side.label.lowercased())"
    }

    /// The tag under someone seated in a boat: **Cox** for a cox in a rowing seat (decision 78),
    /// else "Usually stroke side" when they're on their other side; nil when they suit the seat.
    static func seatNote(_ side: RowingSide?, seat: Int, seatSide: RowingSide?) -> String? {
        if seat > 0 && side == .cox { return RowingSide.cox.label }
        return offSideNote(side, seatSide: seatSide)
    }

    /// Stroke to bow, then the cox: "Piero, Tom, Joe, Marcus · cox Kate".
    static func crewLine(_ seats: [BoatSeat], names: [UUID: String]) -> String {
        let rowers = seats.filter { $0.seat > 0 }.sorted { $0.seat > $1.seat }
            .map { firstName(names[$0.userId]) }
        var text = rowers.joined(separator: ", ")
        if let cox = seats.first(where: { $0.seat == 0 }) {
            text += (text.isEmpty ? "" : " · ") + "cox \(firstName(names[cox.userId]))"
        }
        return text
    }

    /// "Piero" from "Piero Ciobanu".
    static func firstName(_ name: String?) -> String {
        guard let name else { return "?" }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Adding a saved boat to a session (decision 70): "All 4 available", "Lucy can’t make it:
    /// swap her after adding", "Joe is already in M1 four". `available` is nil when the session
    /// has no practice or race answers to check against.
    static func savedBoatCheck(_ boat: SavedBoat, names: [UUID: String], available: Set<UUID>?,
                               cant: Set<UUID>, seatedIn: [UUID: String]) -> (text: String, isProblem: Bool) {
        let people = boat.seats.map(\.userId)
        if let clash = people.first(where: { seatedIn[$0] != nil }), let other = seatedIn[clash] {
            return ("\(firstName(names[clash])) is already in \(other)", true)
        }
        if let missing = people.first(where: { cant.contains($0) }) {
            return ("\(firstName(names[missing])) can’t make it: swap them after adding", true)
        }
        if let available, let unanswered = people.first(where: { !available.contains($0) }) {
            return ("\(firstName(names[unanswered])) hasn’t said they can make it", true)
        }
        if available == nil { return ("\(people.count) in the crew", false) }
        return (people.count == 1 ? "Available" : "All \(people.count) available", false)
    }

    /// The seats a crew keeps when its boat type changes: seats past the new boat's end, or a cox
    /// in a boat without one, are emptied.
    static func seats(_ seats: [BoatSeat], fittingInto type: BoatType) -> [BoatSeat] {
        seats.filter { $0.seat == 0 ? type.isCoxed : $0.seat <= type.rowers }
    }
}
