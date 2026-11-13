//
//  PBGlow.swift
//  Rowing Pals
//

import SwiftUI

/// The new-PB highlight (decision 12; solid since 2026-11-06, no gradients): a solid ring in the
/// records colour around the view, with a soft glow of the same colour behind it. Does nothing when
/// `isActive` is false.
struct PBGlow<S: InsettableShape>: ViewModifier {
    let isActive: Bool
    let shape: S

    func body(content: Content) -> some View {
        if isActive {
            content
                .background {
                    shape
                        .strokeBorder(Tokens.Accent.records, lineWidth: Tokens.Celebration.lineWidth * 3)
                        .blur(radius: Tokens.Celebration.blur)
                        .opacity(0.5)
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape
                        .strokeBorder(Tokens.Accent.records, lineWidth: Tokens.Celebration.lineWidth)
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("New personal best")
        } else {
            content
        }
    }
}

extension View {
    /// Highlights a post that set a new personal best.
    func pbGlow<S: InsettableShape>(_ isActive: Bool, in shape: S) -> some View {
        modifier(PBGlow(isActive: isActive, shape: shape))
    }
}
