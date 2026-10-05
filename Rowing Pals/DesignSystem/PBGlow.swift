//
//  PBGlow.swift
//  Rowing Pals
//

import SwiftUI

/// The new-PB highlight (docs/design/v2-decisions.md #12): colours run around the edge of the
/// view like an RGB LED strip, with a soft glow of the same colours behind it. With Reduce
/// Motion on the colours stay still. Does nothing when `isActive` is false.
///
/// Cheap to run: the gradient is drawn once into its own layer and only that layer turns, as a
/// repeating animation, cut to the edge by a fixed mask. (It used to redraw and re-blur the
/// gradient on every frame, which slowed scrolling and every other animation on screen.)
struct PBGlow<S: InsettableShape>: ViewModifier {
    let isActive: Bool
    let shape: S

    func body(content: Content) -> some View {
        if isActive {
            content
                .background {
                    RunningGradient()
                        .mask {
                            shape
                                .strokeBorder(lineWidth: Tokens.Celebration.lineWidth * 3)
                                .blur(radius: Tokens.Celebration.blur)
                        }
                        .opacity(0.7)
                        .allowsHitTesting(false)
                }
                .overlay {
                    RunningGradient()
                        .mask { shape.strokeBorder(lineWidth: Tokens.Celebration.lineWidth) }
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("New personal best")
        } else {
            content
        }
    }
}

/// The glow's colours, drawn once and turned one full lap every `Tokens.Celebration.period`
/// seconds. Square and as wide as the view's diagonal, so the turning never shows a corner.
private struct RunningGradient: View {
    @State private var isTurning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let side = (geometry.size.width * geometry.size.width + geometry.size.height * geometry.size.height).squareRoot()
            AngularGradient(colors: Tokens.Celebration.glow, center: .center)
                .frame(width: side, height: side)
                .drawingGroup()
                .rotationEffect(.degrees(isTurning ? 360 : 0))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: Tokens.Celebration.period).repeatForever(autoreverses: false)) {
                isTurning = true
            }
        }
        .onChange(of: reduceMotion) { _, reduce in
            if reduce {
                withAnimation(nil) { isTurning = false }
            } else {
                withAnimation(.linear(duration: Tokens.Celebration.period).repeatForever(autoreverses: false)) {
                    isTurning = true
                }
            }
        }
    }
}

extension View {
    /// Highlights a post that set a new personal best.
    func pbGlow<S: InsettableShape>(_ isActive: Bool, in shape: S) -> some View {
        modifier(PBGlow(isActive: isActive, shape: shape))
    }
}
