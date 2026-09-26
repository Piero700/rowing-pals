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

/// Primary: 54 tall, full width, brand gradient, `onBrand` text, soft brand glow.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.button)
            .foregroundStyle(isEnabled ? Tokens.Ink.onBrand : Tokens.Ink.faint)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.primaryButton)
            .padding(.horizontal, 18)
            .background {
                if isEnabled {
                    Capsule().fill(
                        LinearGradient(
                            colors: [Tokens.Accent.brand.mix(with: .white, by: 0.12), Tokens.Accent.brand],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                } else {
                    // Solid when disabled — a faded button lets content show through it.
                    Capsule().fill(Tokens.Surface.raised)
                }
            }
            .overlay {
                ZStack {
                    Capsule().strokeBorder(Tokens.Accent.brand.opacity(0.6), lineWidth: 1)
                    Capsule().inset(by: 1).strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
                }
                .allowsHitTesting(false)
            }
            .shadow(color: Tokens.Accent.brand.opacity(isEnabled ? 0.3 : 0), radius: 11, y: 8)
            .contentShape(Capsule())
            .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

/// Secondary: 52 tall, full width, v3 glass.
struct GlassButtonStyle: ButtonStyle {
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.button)
            .foregroundStyle(Tokens.Ink.primary)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: fullWidth ? Tokens.Size.secondaryButton : Tokens.Size.minTap)
            .padding(.horizontal, fullWidth ? 18 : 14)
            .glassSurface(in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
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
            .frame(minWidth: Tokens.Size.minTap, minHeight: Tokens.Size.minTap)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
            .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

/// Destructive: error colour at 13 % fill, error text, radius 24.
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.button)
            .foregroundStyle(Tokens.System.error)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.secondaryButton)
            .background {
                RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
                    .fill(Tokens.System.error.opacity(0.13))
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous))
            .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

/// Glass pill: 40–44 tall capsule for reactions, comments, filters and follow buttons.
struct GlassPillButtonStyle: ButtonStyle {
    var isPressedState = false
    var minHeight: CGFloat = Tokens.Size.minTap

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Typography.pill)
            .foregroundStyle(isPressedState ? Tokens.Accent.brand : Tokens.Ink.primary)
            .padding(.horizontal, 12)
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
    static func rpPill(isOn: Bool, minHeight: CGFloat = Tokens.Size.minTap) -> GlassPillButtonStyle {
        GlassPillButtonStyle(isPressedState: isOn, minHeight: minHeight)
    }
}

/// A 44 pt glass circle holding one SF Symbol — header actions (search, settings, back).
struct GlassIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var tint: Color = Tokens.Ink.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
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
            GlassIconButton(systemImage: "magnifyingglass", accessibilityLabel: "Search") {}
        }
    }
    .padding(15)
    .background(Tokens.Base.ground)
}
