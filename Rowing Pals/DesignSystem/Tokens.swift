//
//  Tokens.swift
//  Rowing Pals
//

import SwiftUI

// MARK: - Colour

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A colour that resolves differently in light and dark mode, independent of the asset catalog.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

enum Tokens {

    /// The three accents. Each has exactly one job — see the design brief §2.
    /// Never use one of these outside the role named here.
    enum Accent {
        /// Interactive elements, the active tab, links, the Post button.
        static let signal = Color(hex: 0x3AD7E5)
        /// Personal bests and podium ranks 1–3. Nothing else.
        static let pb = Color(hex: 0xF5C542)
        /// The live capture state and its countdown. Nothing else.
        static let live = Color(hex: 0xFF6B5A)
    }

    /// Ground colour. Dark is the primary design; light is a secondary pass.
    enum Base {
        static let dark = Color(hex: 0x0A0C0F)
        static let light = Color(hex: 0xF6F6F7)
        static let ground = Color(light: light, dark: dark)
    }

    /// Primary and secondary text, adapting to colour scheme.
    enum Ink {
        static let primary = Color(light: Base.dark, dark: .white)
        static let secondary = primary.opacity(0.6)
    }

    /// Glass fill and edge values, expressed as opacities to be composited over
    /// whatever material sits behind `GlassSurface`.
    enum Glass {
        static let fillOpacity: Double = 0.13
        /// Bright specular highlight along the upper rim.
        static let edgeTopOpacity: Double = 0.22
        /// Darkened outer edge.
        static let edgeBottomOpacity: Double = 0.30
    }
}

// MARK: - Typography

enum Typography {

    struct Style {
        let size: CGFloat
        let weight: Font.Weight
        /// Tracking expressed as a fraction of point size, matching the brief's em units.
        let trackingEm: CGFloat
        let uppercase: Bool

        var font: Font { .system(size: size, weight: weight, design: .default) }
        var tracking: CGFloat { size * trackingEm }
    }

    /// Session totals, PB times. Large, tight tracking, tabular figures.
    static let displayNumeral = Style(size: 40, weight: .semibold, trackingEm: -0.02, uppercase: false)
    static let body = Style(size: 17, weight: .regular, trackingEm: 0, uppercase: false)
    static let bodySecondary = Style(size: 15, weight: .regular, trackingEm: 0, uppercase: false)
    /// Labels, badges, category chips.
    static let label = Style(size: 12, weight: .semibold, trackingEm: 0.06, uppercase: true)
}

extension View {
    /// Applies a `Typography.Style`'s font, tracking and case.
    func textStyle(_ style: Typography.Style) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .textCase(style.uppercase ? .uppercase : nil)
    }

    /// Every numeral the user reads must sit in a tabular column. Apply this to any
    /// Text that displays a number — splits, times, ranks, distances.
    func tabularNumerals() -> some View {
        monospacedDigit()
    }
}
