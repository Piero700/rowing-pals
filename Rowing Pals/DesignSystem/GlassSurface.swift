//
//  GlassSurface.swift
//  Rowing Pals
//

import SwiftUI

/// Liquid Glass per the design brief: a blurred, translucent fill with a darkened
/// outer edge and a bright specular highlight along the upper rim. A flat translucent
/// rectangle is not glass — both edge treatments must be present.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(shape.fill(Color.white.opacity(Tokens.Glass.fillOpacity)))
            }
            .overlay {
                // Darkened outer edge: brighter at the top, fading to black at the bottom.
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(Tokens.Glass.edgeTopOpacity * 0.4),
                            Color.black.opacity(Tokens.Glass.edgeBottomOpacity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .overlay {
                // Specular top rim: a brighter highlight isolated to the upper edge only.
                shape
                    .stroke(Color.white.opacity(Tokens.Glass.edgeTopOpacity * 2.2), lineWidth: 1)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white.opacity(0), location: 0.22)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
            .clipShape(shape)
    }
}

extension View {
    /// Wraps this view in a Liquid Glass surface — bars, sheets, chips.
    func glassSurface(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
    }
}
