//
//  BoatPalette.swift
//  Rowing Pals
//

import SwiftUI

/// Boat colours (decision 87): a coach colours a boat so it's easy to pick out. These are the ready
/// swatches on the crewing screen — any other colour comes from Apple's colour picker — and the
/// conversions to and from the "#RRGGBB" the database keeps. A boat's colour is the coach's data,
/// not one of the app's accent roles.
enum BoatPalette {
    struct Swatch: Identifiable, Hashable {
        let name: String
        let hex: String
        var id: String { hex }
    }

    static let swatches: [Swatch] = [
        Swatch(name: "Red", hex: "#E5484D"),
        Swatch(name: "Orange", hex: "#F76B15"),
        Swatch(name: "Yellow", hex: "#FFC53D"),
        Swatch(name: "Green", hex: "#30A46C"),
        Swatch(name: "Teal", hex: "#12A594"),
        Swatch(name: "Blue", hex: "#0090FF"),
        Swatch(name: "Navy", hex: "#3E63DD"),
        Swatch(name: "Purple", hex: "#8E4EC6"),
        Swatch(name: "Pink", hex: "#D6409F"),
        Swatch(name: "Brown", hex: "#A07553"),
        Swatch(name: "Grey", hex: "#8B8D98"),
        Swatch(name: "White", hex: "#F0F0F3"),
        Swatch(name: "Black", hex: "#1C1C1F")
    ]

    /// The colour for "#RRGGBB"; nil for none or anything else.
    static func color(_ hex: String?) -> Color? {
        guard let value = normalised(hex), let number = UInt32(String(value.dropFirst()), radix: 16) else { return nil }
        return Color(hex: number)
    }

    /// "#RRGGBB" for a colour picked in Apple's colour picker.
    static func hex(_ color: Color) -> String {
        let resolved = color.resolve(in: EnvironmentValues())
        func byte(_ component: Float) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(resolved.red), byte(resolved.green), byte(resolved.blue))
    }

    /// "Red", or "Custom colour" for one that isn't a swatch; nil for none.
    static func name(_ hex: String?) -> String? {
        guard let value = normalised(hex) else { return nil }
        return swatches.first { $0.hex == value }?.name ?? "Custom colour"
    }

    /// "#RRGGBB" in capitals, or nil.
    static func normalised(_ hex: String?) -> String? {
        guard let hex else { return nil }
        let value = hex.trimmingCharacters(in: .whitespaces).uppercased()
        guard value.count == 7, value.hasPrefix("#"), value.dropFirst().allSatisfy(\.isHexDigit) else { return nil }
        return value
    }
}
