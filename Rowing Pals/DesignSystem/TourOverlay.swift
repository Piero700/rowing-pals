//
//  TourOverlay.swift
//  Rowing Pals
//

import SwiftUI

/// The first-run tour (decision 109): the screen dimmed except round one tab bar control, and a
/// glass card above it saying what that part of the app is for, with Skip and Next. Taps elsewhere
/// do nothing while it shows, so the tour can't be left half-way by accident.
struct TourOverlay: View {
    let steps: [TourStep]
    @Binding var index: Int
    let targets: [TourStep.Target: Anchor<CGRect>]
    /// Skip, or Done on the last card.
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            if steps.indices.contains(index) {
                let step = steps[index]
                let hole = targets[step.target].map { proxy[$0].insetBy(dx: -Tokens.Tour.cutoutInset, dy: -Tokens.Tour.cutoutInset) }
                ZStack {
                    TourScrim(hole: hole)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        TourCard(step: step, progress: TourRules.progressText(index: index, count: steps.count),
                                 isLast: index == steps.count - 1, onSkip: onFinish, onNext: next)
                            .padding(.horizontal, Tokens.Spacing.screen)
                        // Just above the control; centred on screen if it can't be found.
                        if let hole {
                            Color.clear
                                .frame(height: max(0, proxy.size.height - hole.minY + Tokens.Tour.cardGap))
                                .allowsHitTesting(false)
                        } else {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: index)
            }
        }
        .ignoresSafeArea()
    }

    private func next() {
        if index < steps.count - 1 {
            index += 1
        } else {
            onFinish()
        }
    }
}
