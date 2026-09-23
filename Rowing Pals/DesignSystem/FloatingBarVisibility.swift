//
//  FloatingBarVisibility.swift
//  Rowing Pals
//

import SwiftUI

/// Drives the custom floating tab bar's scroll-linked behaviour now that
/// the redesign's two-separate-glass-capsules bottom nav (phase A rework)
/// can't be a native `TabView`, so it can't get `.tabBarMinimizeBehavior`
/// for free any more. One instance lives in `RootView` and is shared via
/// `.environment()`; every tab's own root `ScrollView` reports its offset
/// into it via `.tracksFloatingBar()` below.
///
/// Real-device feedback (2026-09-17) drove two changes from the first cut:
/// per-frame scroll deltas flipped state on the slightest wobble, which
/// read as janky — this now accumulates distance *in one direction*
/// (resetting on a direction change) and only flips once that crosses a
/// real threshold, the standard "hide on scroll" pattern. And the nav
/// pill (not the Log button — see `FloatingTabBar`) fully hides rather
/// than shrinking to near-zero, per explicit direction: "the 3 buttons
/// should disappear then the plus should get slightly smaller... but it
/// should stay on the page for easy access."
@Observable
final class FloatingBarVisibility {
    var isExpanded = true

    private var lastOffset: CGFloat = 0
    private var accumulated: CGFloat = 0
    private var lastDirection: Int = 0
    private let hideThreshold: CGFloat = 32
    private let showThreshold: CGFloat = 12

    func handleScroll(offset: CGFloat) {
        let delta = offset - lastOffset
        lastOffset = offset

        // Always expanded at or near the top, regardless of accumulated
        // state — rubber-banding above content must never leave the bar
        // hidden.
        guard offset > 0 else {
            accumulated = 0
            lastDirection = 0
            setExpanded(true)
            return
        }
        guard abs(delta) > 0.5 else { return }

        let direction = delta > 0 ? 1 : -1
        if direction != lastDirection {
            accumulated = 0
            lastDirection = direction
        }
        accumulated += abs(delta)

        if direction == 1, accumulated > hideThreshold {
            setExpanded(false)
        } else if direction == -1, accumulated > showThreshold {
            setExpanded(true)
        }
    }

    private func setExpanded(_ value: Bool) {
        guard isExpanded != value else { return }
        withAnimation(.easeOut(duration: 0.3)) { isExpanded = value }
    }
}

private struct FloatingBarScrollTracker: ViewModifier {
    @Environment(FloatingBarVisibility.self) private var visibility

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newOffset in
            visibility.handleScroll(offset: newOffset)
        }
    }
}

extension View {
    /// Apply to a tab's own root `ScrollView` so the floating bar reacts
    /// to it. No-op if no `FloatingBarVisibility` is in the environment
    /// (e.g. a `#Preview` of the screen on its own).
    func tracksFloatingBar() -> some View {
        modifier(FloatingBarScrollTracker())
    }
}
