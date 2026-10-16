//
//  RowingSide.swift
//  Rowing Pals
//

/// The side a rower rows on in a pair, four or eight (decision 67): stroke side, bow side, or
/// either. Mirrors `profiles.side`; coaches see it when they seat the rower in a boat.
enum RowingSide: String, Codable, CaseIterable {
    case stroke, bow, both

    /// As the side picker and coaches show it.
    var label: String {
        switch self {
        case .stroke: "Stroke side"
        case .bow: "Bow side"
        case .both: "Both"
        }
    }
}
