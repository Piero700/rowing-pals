//
//  Buttons.swift
//  Rowing Pals
//

import SwiftUI

/// The v3 button family (docs/design/rowing-pals-v3-spec.md §Layout — Buttons). Every style:
/// - is hit-testable across its **whole** shape, not just where text or an icon is drawn (a
///   `.plain` button only answers taps on its drawn pixels, which is what let taps fall through
///   the old tab bar onto posts underneath);
/// - is at least `Tokens.Size.minTap` (44 pt) tall;
/// - scales to `Tokens.Motion.pressScale` while pressed, unless Reduce Motion is on.
///
/// Use as `.buttonStyle(.rpPrimary)`, `.rpGlass`, `.rpText`, `.rpDestructive`.

/// Shared press feedback.
private struct PressEffect: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? Tokens.Motion.pressScale : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isPressed)
    }
}

/// The grouped style's button shape (decision 97, app-wide 2026-11-05): a rounded rectangle.
private let buttonShape = RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)

/// Primary: full width, brand fill, `onBrand` text; compact, without the old glow.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.button)
            .foregroundStyle(isEnabled ? Tokens.Ink.onBrand : Tokens.Ink.faint)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.primaryButton)
            .padding(.horizontal, Tokens.Spacing.card)
            .background {
                if isEnabled {
                    buttonShape.fill(
                        LinearGradient(
                            colors: [Tokens.Accent.brand.mix(with: .white, by: 0.08), Tokens.Accent.brand],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                } else {
                    // Solid when disabled — a faded button lets content show through it.
                    buttonShape.fill(Tokens.Surface.raised)
                }
            }
            .overlay {
                buttonShape.inset(by: Tokens.Grouped.hairline).strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center),
                    lineWidth: Tokens.Grouped.hairline
                )
                .allowsHitTesting(false)
            }
            .contentShape(buttonShape)
            .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

/// Secondary: glass. Full width it's a rounded rectangle like the primary; compact it stays a capsule.
struct GlassButtonStyle: ButtonStyle {
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .textStyle(Typography.button)
            .foregroundStyle(Tokens.Ink.primary)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: fullWidth ? Tokens.Size.secondaryButton : Tokens.Size.minTap)
            .padding(.horizontal, fullWidth ? Tokens.Spacing.card : Tokens.Spacing.loose)
        return Group {
            if fullWidth {
                label.glassSurface(in: buttonShape).contentShape(buttonShape)
            } else {
                label.glassSurface(in: Capsule()).contentShape(Capsule())
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
        .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

/// Text button: 44 tall, brand text, no background.
struct TextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.button)
            .foregroundStyle(Tokens.Accent.brand)
            .frame(minWidth: Tokens.Size.minTap, minHeight: Tokens.Size.control)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
            .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

/// Destructive: error colour at 13 % fill, error text, the button corners.
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.button)
            .foregroundStyle(Tokens.System.error)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.secondaryButton)
            .background {
                buttonShape.fill(Tokens.System.error.opacity(0.13))
            }
            .contentShape(buttonShape)
            .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

/// Glass pill: 40–44 tall capsule for reactions, comments, filters and follow buttons.
struct GlassPillButtonStyle: ButtonStyle {
    var isPressedState = false
    var minHeight: CGFloat = Tokens.Size.control

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.pill)
            .foregroundStyle(isPressedState ? Tokens.Accent.brand : Tokens.Ink.primary)
            .padding(.horizontal, Tokens.Spacing.loose)
            .frame(minWidth: Tokens.Size.minTap, minHeight: minHeight)
            .background {
                if isPressedState { Capsule().fill(Tokens.Accent.brandSoft) }
            }
            .glassSurface(in: Capsule())
            .contentShape(Capsule())
            .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var rpPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var rpGlass: GlassButtonStyle { GlassButtonStyle() }
    static var rpGlassCompact: GlassButtonStyle { GlassButtonStyle(fullWidth: false) }
}

extension ButtonStyle where Self == TextButtonStyle {
    static var rpText: TextButtonStyle { TextButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var rpDestructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

extension ButtonStyle where Self == GlassPillButtonStyle {
    static var rpPill: GlassPillButtonStyle { GlassPillButtonStyle() }
    static func rpPill(isOn: Bool, minHeight: CGFloat = Tokens.Size.control) -> GlassPillButtonStyle {
        GlassPillButtonStyle(isPressedState: isOn, minHeight: minHeight)
    }
}

/// A 44 pt glass circle holding one icon (decision 80) — header actions (search, settings, back).
struct GlassIconButton: View {
    let icon: RPIcon
    let accessibilityLabel: String
    var tint: Color = Tokens.Ink.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RPIconView(icon: icon)
                .textStyle(Typography.cardTitle)
                .foregroundStyle(tint)
                .frame(width: Tokens.Size.iconButton, height: Tokens.Size.iconButton)
                .glassSurface(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Press feedback only — the label draws itself.
struct IconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

extension View {
    /// Makes this whole view — every pixel of its frame, not just its text — a real button
    /// with press feedback. Use for tappable rows, tiles and chips instead of
    /// `onTapGesture`, which gives no press feedback, isn't announced as a button by
    /// VoiceOver, and can lose to a scroll or a parent's gesture.
    func asButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self.contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
    }
}

#Preview {
    VStack(spacing: 14) {
        Button("Post session") {}.buttonStyle(.rpPrimary)
        Button("Enter session manually") {}.buttonStyle(.rpGlass)
        Button("I'm not in a club") {}.buttonStyle(.rpText)
        Button("Delete account") {}.buttonStyle(.rpDestructive)
        HStack {
            Button("🔥 3") {}.buttonStyle(.rpPill(isOn: true, minHeight: 40))
            Button("👏 1") {}.buttonStyle(.rpPill(isOn: false, minHeight: 40))
            GlassIconButton(icon: .search, accessibilityLabel: "Search") {}
        }
    }
    .padding(16)
    .background(Tokens.Base.ground)
}
