//
//  PBGlow.swift
//  Rowing Pals
//

import SwiftUI

/// The new-PB highlight (docs/design/v2-decisions.md #12): colours run around the edge of the
/// view like an RGB LED strip, with a soft glow of the same colours behind it. With Reduce
/// Motion on the colours stay still. Does nothing when `isActive` is false.
struct PBGlow<S: InsettableShape>: ViewModifier {
    let isActive: Bool
    let shape: S

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive {
            content
                .background {
                    TimelineView(.animation(paused: reduceMotion)) { context in
                        let angle = rotation(at: context.date)
                        shape
                            .strokeBorder(gradient(angle), lineWidth: Tokens.Celebration.lineWidth * 3)
                            .blur(radius: Tokens.Celebration.blur)
                            .opacity(0.7)
                    }
                    .allowsHitTesting(false)
                }
                .overlay {
                    TimelineView(.animation(paused: reduceMotion)) { context in
                        shape.strokeBorder(gradient(rotation(at: context.date)), lineWidth: Tokens.Celebration.lineWidth)
                    }
                    .allowsHitTesting(false)
                }
                .accessibilityLabel("New personal best")
        } else {
            content
        }
    }

    private func rotation(at date: Date) -> Angle {
        guard !reduceMotion else { return .zero }
        let fraction = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Tokens.Celebration.period)
            / Tokens.Celebration.period
        return .degrees(fraction * 360)
    }

    private func gradient(_ angle: Angle) -> AngularGradient {
        AngularGradient(colors: Tokens.Celebration.glow, center: .center, angle: angle)
    }
}

extension View {
    /// Highlights a post that set a new personal best.
    func pbGlow<S: InsettableShape>(_ isActive: Bool, in shape: S) -> some View {
        modifier(PBGlow(isActive: isActive, shape: shape))
    }
}
