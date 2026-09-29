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

        /// Tinted backgrounds for each role above — real per-theme alpha values from the
        /// prototype's `--brandSoft`/`--accentSoft`/`--goldSoft`/`--goodSoft`, not a flat
        /// `.opacity()` multiply (the light and dark alphas differ, e.g. brandSoft is 14% in
        /// dark but 12% in light — a plain `.opacity()` call would get that wrong).
        static let brandSoft = Color(light: Color(hex: 0x214FA3, opacity: 0.12), dark: Color(hex: 0x91B8FF, opacity: 0.14))
        static let recordsSoft = Color(light: Color(hex: 0x67409B, opacity: 0.10), dark: Color(hex: 0xC6ADFF, opacity: 0.12))
        static let rankSoft = Color(light: Color(hex: 0x84500B, opacity: 0.10), dark: Color(hex: 0xEFC37C, opacity: 0.12))
        static let successSoft = Color(light: Color(hex: 0x176A4A, opacity: 0.10), dark: Color(hex: 0x78D7AC, opacity: 0.12))
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
        /// v3 `bg` — the outer background behind full-screen covers and sheets.
        static let outer = Color(light: Color(hex: 0xDFE3EB), dark: Color(hex: 0x09090B))
    }

    /// Surface levels above `Base` — new in the redesign. Previously the app only had `Base`
    /// plus ad hoc `.glassSurface()`; these give flat (non-glass) cards and rows a real,
    /// consistent two-step elevation instead of opacity-tinted ink.
    enum Surface {
        static let card = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1B1C21))
        static let raised = Color(light: Color(hex: 0xDCE2EC), dark: Color(hex: 0x292C34))
        static let line = Color(light: Color(hex: 0x949EAE), dark: Color(hex: 0x464A56))
        /// v3 `cardEdge` — the 1 pt border around cards.
        static let cardEdge = Color(light: Color(hex: 0xA8B1BF), dark: Color(hex: 0x464A56, opacity: 0.7))
    }

    /// Primary, secondary and tertiary text — three real, hand-tuned values now (matching the
    /// redesign), not `secondary` computed as `primary.opacity(0.6)` the way it was before.
    enum Ink {
        static let primary = Color(light: Color(hex: 0x111723), dark: Color(hex: 0xF7F8FC))
        static let secondary = Color(light: Color(hex: 0x3E4C61), dark: Color(hex: 0xBBC0CE))
        static let faint = Color(light: Color(hex: 0x4E5C70), dark: Color(hex: 0xA3ABBA))
        /// v3 `onBrand` — text and icons on a brand-filled (primary) button.
        static let onBrand = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x09090B))
    }

    /// The v3 liquid-glass layer (docs/design/rowing-pals-v3-spec.md §Liquid glass): segmented
    /// controls, the bottom nav, the Log button, header icon buttons, secondary buttons, pills.
    /// Applied by `glassSurface(_:)` — never assembled by hand in a view.
    enum Glass {
        static let fill = Color(light: Color(hex: 0xFFFFFF, opacity: 0.52), dark: Color(hex: 0x3A3E4A, opacity: 0.42))
        /// The selected thumb of a segmented control or tab.
        static let fillStrong = Color(light: Color(hex: 0xFFFFFF, opacity: 0.92), dark: Color(hex: 0x5C6272, opacity: 0.55))
        static let edge = Color(light: Color(hex: 0x283755, opacity: 0.16), dark: Color(hex: 0xFFFFFF, opacity: 0.16))
        /// Inner top highlight — the specular rim.
        static let highlight = Color(light: Color(hex: 0xFFFFFF, opacity: 0.95), dark: Color(hex: 0xFFFFFF, opacity: 0.28))
        /// Inner bottom shade — the darkened edge.
        static let lowlight = Color(light: Color(hex: 0x1E2D4B, opacity: 0.08), dark: Color(hex: 0x000000, opacity: 0.22))
        static let shadow = Color(light: Color(hex: 0x192846, opacity: 0.12), dark: Color(hex: 0x000000, opacity: 0.22))
        static let shadowRadius: CGFloat = 11
        static let shadowY: CGFloat = 7
    }

    /// v3 corner radii. Interactive controls (buttons, pills, segmented, nav) use a `Capsule`.
    enum Radius {
        static let card: CGFloat = 30
        /// Inputs, club rows, split rows, PB tiles.
        static let input: CGFloat = 24
        static let estimate: CGFloat = 22
        static let photo: CGFloat = 22
        static let iconChoice: CGFloat = 20
        static let workoutLink: CGFloat = 18
        static let photoInset: CGFloat = 17
        static let select: CGFloat = 15
        static let crest: CGFloat = 13
    }

    /// v3 spacing.
    enum Spacing {
        static let screen: CGFloat = 15
        static let headerHorizontal: CGFloat = 18
        static let card: CGFloat = 15
        static let tight: CGFloat = 8
        static let gap: CGFloat = 10
        static let loose: CGFloat = 12
        static let sectionTop: CGFloat = 20
        static let sectionBottom: CGFloat = 9
        /// Bottom inset on tab screens so content clears the floating nav.
        static let tabScrollBottom: CGFloat = 90
    }

    /// v3 component sizes.
    enum Size {
        /// Nothing tappable is smaller than this, in either direction.
        static let minTap: CGFloat = 44
        static let primaryButton: CGFloat = 54
        static let secondaryButton: CGFloat = 52
        static let input: CGFloat = 52
        static let navHeight: CGFloat = 58
        static let navSideInset: CGFloat = 16
        static let navBottomInset: CGFloat = 6
        static let navGap: CGFloat = 4
        static let headerMinHeight: CGFloat = 61
        static let iconButton: CGFloat = 44
    }

    /// The new-PB celebration (docs/design/v2-decisions.md #12): an RGB-LED style glow that
    /// runs around a post when its test result beat the rower's previous best. Its own palette on
    /// purpose — no accent role means "celebrate", and borrowing one would blur that role.
    enum Celebration {
        static let glow: [Color] = [
            Color(hex: 0xFF5F6D), Color(hex: 0xFFC371), Color(hex: 0x7CF5B0),
            Color(hex: 0x5EC8FF), Color(hex: 0xB28BFF), Color(hex: 0xFF5F6D)
        ]
        static let lineWidth: CGFloat = 2.5
        static let blur: CGFloat = 14
        /// One full lap of the colours.
        static let period: Double = 4
    }

    /// v3 motion. Callers skip animation when Reduce Motion is on.
    enum Motion {
        /// Press feedback on every button.
        static let pressScale: CGFloat = 0.96
        /// The segmented thumb's slide — 0.32 s with a slight overshoot, like the design's
        /// cubic-bezier(.3, 1.4, .5, 1).
        static let thumb = Animation.spring(response: 0.32, dampingFraction: 0.72)
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

    // v3 type scale (docs/design/rowing-pals-v3-spec.md §Typography), set in SF Pro per
    // decision 13. Numeric weights from the design map to the nearest SF weight:
    // 700–760 → bold, 780–820 → heavy.

    /// Large title on tab screens.
    static let largeTitle = Style(size: 29, weight: .bold, trackingEm: -0.04, uppercase: false)
    static let onboardingTitle = Style(size: 33, weight: .bold, trackingEm: -0.05, uppercase: false)
    /// Title on pushed screens.
    static let navTitle = Style(size: 17, weight: .bold, trackingEm: -0.01, uppercase: false)
    static let profileName = Style(size: 23, weight: .bold, trackingEm: 0, uppercase: false)
    static let bigResult = Style(size: 36, weight: .heavy, trackingEm: -0.055, uppercase: false)
    static let reviewResult = Style(size: 29, weight: .heavy, trackingEm: -0.055, uppercase: false)
    static let heroNumber = Style(size: 32, weight: .bold, trackingEm: -0.031, uppercase: false)
    static let bodyV3 = Style(size: 16, weight: .regular, trackingEm: 0, uppercase: false)
    static let name = Style(size: 15, weight: .bold, trackingEm: 0, uppercase: false)
    /// The title of a settings row or switch row.
    static let rowTitle = Style(size: 14, weight: .bold, trackingEm: 0, uppercase: false)
    static let meta = Style(size: 12.8, weight: .regular, trackingEm: 0, uppercase: false)
    static let sectionTitle = Style(size: 12, weight: .heavy, trackingEm: 0.09, uppercase: true)
    static let overline = Style(size: 12, weight: .bold, trackingEm: 0.1, uppercase: true)
    static let metricLabel = Style(size: 12, weight: .bold, trackingEm: 0.07, uppercase: true)
    static let metricValue = Style(size: 17, weight: .bold, trackingEm: 0, uppercase: false)
    /// A rank in a stats card ("#5"), v3 §08's rankings card.
    static let rankValue = Style(size: 16, weight: .bold, trackingEm: 0, uppercase: false)
    /// The label under a rank or stat ("2k test").
    static let statLabel = Style(size: 12, weight: .regular, trackingEm: 0, uppercase: false)
    static let navLabel = Style(size: 11, weight: .bold, trackingEm: 0, uppercase: false)
    static let segment = Style(size: 14, weight: .bold, trackingEm: 0, uppercase: false)
    static let pill = Style(size: 13, weight: .bold, trackingEm: 0, uppercase: false)
    static let button = Style(size: 16, weight: .bold, trackingEm: 0, uppercase: false)

    // Pre-v3 styles, still used by screens not yet rebuilt in step 3.

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
