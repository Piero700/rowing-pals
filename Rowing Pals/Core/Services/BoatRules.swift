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

    /// The side a seat's oar is on; nil for a sculling boat or the cox.
    static func side(ofSeat seat: Int, type: BoatType, rigging: Rigging) -> RowingSide? {
        guard !type.isSculling, seat > 0 else { return nil }
        let sameParityAsStroke = (type.rowers - seat) % 2 == 0
        switch rigging {
        case .stroke: return sameParityAsStroke ? .stroke : .bow
        case .bow: return sameParityAsStroke ? .bow : .stroke
        }
    }

    /// Whether the oar sits on the drawing's right: bow side in a sweep boat; in a sculling boat
    /// the names alternate, bow on the right.
    static func isOnRight(seat: Int, type: BoatType, rigging: Rigging) -> Bool {
        if let side = side(ofSeat: seat, type: type, rigging: rigging) { return side == .bow }
        return seat % 2 == 1
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

    /// Whether someone who rows `side` suits a seat on `seatSide` (either suits anyone).
    static func fits(_ side: RowingSide?, seatSide: RowingSide?) -> Bool {
        guard let seatSide, let side else { return true }
        return side == .both || side == seatSide
    }

    /// "Usually stroke side" for someone seated on their other side; nil otherwise.
    static func offSideNote(_ side: RowingSide?, seatSide: RowingSide?) -> String? {
        guard let side, let seatSide, side != .both, side != seatSide else { return nil }
        return "Usually \(side.label.lowercased())"
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
