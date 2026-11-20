//
//  FirstRunTour.swift
//  Rowing Pals
//

import SwiftUI

/// Runs the first-run tour (decision 109) over a version's tabs: starts it once, shortly after the
/// version first opens while helper text is on, and again each time Settings → Help → Show the tour
/// again is tapped. Each card shows its tab behind it; finishing or skipping goes back to
/// the first tab and remembers the tour was seen, on this phone, for this version.
struct FirstRunTour: ViewModifier {
    let steps: [TourStep]
    let barVisibility: FloatingBarVisibility
    /// Shows the card's tab behind it.
    let onStep: (TourStep) -> Void
    let onFinish: () -> Void

    @AppStorage private var seen: Bool
    /// Settings → Help → Show the tour again bumps it.
    @AppStorage(TourRules.replayKey) private var replays = 0
    @Environment(\.showsGuidance) private var showsGuidance
    @State private var index: Int?

    init(mode: AppMode, steps: [TourStep], barVisibility: FloatingBarVisibility,
         onStep: @escaping (TourStep) -> Void, onFinish: @escaping () -> Void) {
        self.steps = steps
        self.barVisibility = barVisibility
        self.onStep = onStep
        self.onFinish = onFinish
        _seen = AppStorage(wrappedValue: false, TourRules.seenKey(mode))
    }

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(TourTargetKey.self) { targets in
                if index != nil {
                    TourOverlay(steps: steps, index: Binding(get: { index ?? 0 }, set: { index = $0 }),
                                targets: targets, onFinish: finish)
                }
            }
            .task {
                // A moment for the first screen to draw before the tour covers it.
                try? await Task.sleep(for: .milliseconds(700))
                if TourRules.startsByItself(seen: seen, showsGuidance: showsGuidance) { start() }
            }
            .onChange(of: replays) {
                // Show the tour again, from Settings.
                start()
            }
            .onChange(of: index) { _, now in
                if let now, steps.indices.contains(now) { onStep(steps[now]) }
            }
    }

    private func start() {
        guard index == nil, let first = steps.first else { return }
        barVisibility.isExpanded = true
        index = 0
        onStep(first)
    }

    private func finish() {
        index = nil
        seen = true
        onFinish()
    }
}
