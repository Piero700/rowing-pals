//
//  Glass.swift
//  Rowing Pals
//

import SwiftUI

/// Native Liquid Glass helpers beyond the plain card surface in
/// `GlassSurface.swift` — tinted/interactive glass, and grouping adjacent
/// glass elements so they blend into one another.
extension View {
    /// An interactive glass surface tinted with one of the three accent
    /// tokens — for a control the user taps, not a static card. `.interactive()`
    /// gives it the scale/bounce/shimmer response Liquid Glass controls have.
    func interactiveGlassSurface(cornerRadius: CGFloat = 24, tint: Color) -> some View {
        glassEffect(
            .regular.tint(tint).interactive(),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

/// Groups adjacent glass elements — e.g. a row of small glass icon buttons —
/// so the system blends and morphs between them instead of rendering each in
/// isolation. Thin wrapper kept here so call sites don't need to know the
/// container type's name.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat?
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content()
        }
    }
}
