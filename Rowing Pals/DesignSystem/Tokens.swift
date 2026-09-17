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

/// Redesigned 2026-09-17 — see docs/design/rowing-pals-redesign-handoff-v2.md §1 for the source
/// values and the "blue actions, lilac records, amber rank, green success" role statement this
/// mirrors exactly. Replaces the original 3-colour cyan/gold/coral set.
enum Tokens {

    /// Four accent roles, each with exactly one job. Never use one of these outside the role
    /// named here — see the handoff doc if a new use case doesn't obviously fit one of them.
    enum Accent {
        /// Interactive elements, the active tab, links, the Log/Post button.
        static let brand = Color(light: Color(hex: 0x214FA3), dark: Color(hex: 0x91B8FF))
        /// Personal bests and other "records" — PB values and badges, avatars, the rank-hero
        /// card. Broader than the old `pb` role (which was PB text + podium ranks only) to match
        /// the redesign's actual usage; podium/leaderboard-rank colouring specifically may move
        /// to `rank` when Rankings is rebuilt (phase H) — not yet reconciled at the token level.
        static let records = Color(light: Color(hex: 0x67409B), dark: Color(hex: 0xC6ADFF))
        /// Rank prominence — the #1 leaderboard row and the "↑ 2 places" movement indicator.
        /// Nothing else.
        static let rank = Color(light: Color(hex: 0x84500B), dark: Color(hex: 0xEFC37C))
        /// Success confirmation and "on" toggle states. Nothing else.
        static let success = Color(light: Color(hex: 0x176A4A), dark: Color(hex: 0x78D7AC))
    }

    /// Semantic system colour — not one of the four celebratory accent roles above. Used for
    /// error and destructive text/controls throughout the app (this absorbs what the old
    /// `Accent.live` coral was doing everywhere except the capture screen's actual countdown,
    /// which the redesign removes outright — see CaptureView.swift, phase F).
    enum System {
        static let error = Color(light: Color(hex: 0xC93C36), dark: Color(hex: 0xFF766F))
    }

    /// Ground colour — the screen/card base, not the outer page background the web prototype
    /// also has (native screens have no "outer page" to distinguish).
    enum Base {
        static let dark = Color(hex: 0x101114)
        static let light = Color(hex: 0xEDF0F5)
        static let ground = Color(light: light, dark: dark)
    }

    /// Surface levels above `Base` — new in the redesign. Previously the app only had `Base`
    /// plus ad hoc `.glassSurface()`; these give flat (non-glass) cards and rows a real,
    /// consistent two-step elevation instead of opacity-tinted ink.
    enum Surface {
        static let card = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1B1C21))
        static let raised = Color(light: Color(hex: 0xDCE2EC), dark: Color(hex: 0x292C34))
        static let line = Color(light: Color(hex: 0x949EAE), dark: Color(hex: 0x464A56))
    }

    /// Primary, secondary and tertiary text — three real, hand-tuned values now (matching the
    /// redesign), not `secondary` computed as `primary.opacity(0.6)` the way it was before.
    enum Ink {
        static let primary = Color(light: Color(hex: 0x111723), dark: Color(hex: 0xF7F8FC))
        static let secondary = Color(light: Color(hex: 0x3E4C61), dark: Color(hex: 0xBBC0CE))
        static let faint = Color(light: Color(hex: 0x4E5C70), dark: Color(hex: 0xA3ABBA))
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
