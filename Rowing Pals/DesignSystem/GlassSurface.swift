//
//  GlassSurface.swift
//  Rowing Pals
//

import SwiftUI

/// The v3 liquid-glass recipe (docs/design/rowing-pals-v3-spec.md §Liquid glass): native Liquid
/// Glass tinted with `Tokens.Glass.fill`, a 1 pt `edge` border, a specular top rim and a
/// darkened bottom edge on the inside, and the glass shadow. With Reduce Transparency on, a
/// solid `Surface.raised` fill replaces the glass, as the design specifies.
///
/// Native glass stays underneath (CLAUDE.md: Liquid Glass is permanent) — the v3 layers sit on
/// top of it to match the design's exact tint and edges.
struct GlassChrome<S: InsettableShape>: ViewModifier {
    let shape: S
    /// The selected thumb look — stronger fill, lighter shadow.
    var isSelected = false
    /// Off for glass drawn inside another glass container (a thumb inside a segmented
    /// control), where a second blur layer only muddies the first.
    var usesNativeGlass = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background { fill }
            .overlay { edges.allowsHitTesting(false) }
            .shadow(
                color: isSelected ? Color.black.opacity(0.18) : Tokens.Glass.shadow,
                radius: isSelected ? 4 : Tokens.Glass.shadowRadius,
                y: isSelected ? 2 : Tokens.Glass.shadowY
            )
    }

    @ViewBuilder
    private var fill: some View {
        let tint = isSelected ? Tokens.Glass.fillStrong : Tokens.Glass.fill
        if reduceTransparency {
            shape.fill(isSelected ? Tokens.Surface.card : Tokens.Surface.raised)
        } else if usesNativeGlass {
            Color.clear.glassEffect(.regular.tint(tint), in: shape)
        } else {
            shape.fill(tint)
        }
    }

    private var edges: some View {
        ZStack {
            shape.strokeBorder(Tokens.Glass.edge, lineWidth: 1)
            shape.inset(by: 1).strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: Tokens.Glass.highlight, location: 0),
                        .init(color: .clear, location: 0.2),
                        .init(color: .clear, location: 0.8),
                        .init(color: Tokens.Glass.lowlight, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
    }
}

extension View {
    /// v3 glass in a rounded rectangle — cards, chips and other non-capsule glass.
    func glassSurface(cornerRadius: CGFloat = Tokens.Radius.input) -> some View {
        modifier(GlassChrome(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    /// v3 glass in any shape — `Capsule()` for buttons, pills and segmented controls, `Circle()`
    /// for icon buttons.
    func glassSurface<S: InsettableShape>(in shape: S, isSelected: Bool = false, usesNativeGlass: Bool = true) -> some View {
        modifier(GlassChrome(shape: shape, isSelected: isSelected, usesNativeGlass: usesNativeGlass))
    }
}
