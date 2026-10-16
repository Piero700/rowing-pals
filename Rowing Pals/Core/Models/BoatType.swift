//
//  BoatType.swift
//  Rowing Pals
//

import Foundation

/// A boat's class (decision 67): single, double, pair, four (coxless or coxed), quad, eight.
/// Mirrors `session_boats.boat_type` and `saved_boats.boat_type`.
nonisolated enum BoatType: String, Codable, CaseIterable {
    case single = "1x"
    case double = "2x"
    case pair = "2-"
    case four = "4-"
    case coxedFour = "4+"
    case quad = "4x"
    case eight = "8+"

    /// "4−", with a real minus sign, as the canvas writes it.
    var label: String { rawValue.replacingOccurrences(of: "-", with: "\u{2212}") }

    /// Rowers, not counting a cox.
    var rowers: Int {
        switch self {
        case .single: 1
        case .double, .pair: 2
        case .four, .coxedFour, .quad: 4
        case .eight: 8
        }
    }

    var isCoxed: Bool { self == .coxedFour || self == .eight }

    /// Sculling boats have two oars each, so no sides and no rigging.
    var isSculling: Bool { self == .single || self == .double || self == .quad }

    /// Everyone in it, cox included.
    var crewSize: Int { rowers + (isCoxed ? 1 : 0) }
}
