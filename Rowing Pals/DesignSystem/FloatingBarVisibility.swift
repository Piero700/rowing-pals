//
//  FloatingBarVisibility.swift
//  Rowing Pals
//

import SwiftUI

/// Drives the custom floating tab bar's shrink-on-scroll-down,
/// expand-on-scroll-up behaviour (CLAUDE.md's Liquid Glass rule) now that
/// the redesign's two-separate-glass-capsules bottom nav (phase A rework)
/// can't be a native `TabView`, so it can't get `.tabBarMinimizeBehavior`
/// for free any more. One instance lives in `RootView` and is shared via
/// `.environment()`; every tab's own root `ScrollView` reports its offset
/// into it via `.tracksFloatingBar()` below.
@Observable
final class FloatingBarVisibility {
    var isExpanded = true
    private var lastOffset: CGFloat = 0
    /// Ignore tiny jitter (rubber-banding, momentum settling) so the bar
    /// doesn't flicker between states on a near-stationary scroll.
    private let threshold: CGFloat = 8

    func handleScroll(offset: CGFloat) {
        defer { lastOffset = offset }
        // Always expanded at or near the top — matches the native
        // behaviour, and avoids the bar starting collapsed on a screen
        // shorter than its own scroll-back threshold.
        guard offset > threshold else {
            if !isExpanded { withAnimation(.easeOut(duration: 0.25)) { isExpanded = true } }
            return
        }
        let delta = offset - lastOffset
        if delta > threshold, isExpanded {
            withAnimation(.easeOut(duration: 0.25)) { isExpanded = false }
        } else if delta < -threshold, !isExpanded {
            withAnimation(.easeOut(duration: 0.25)) { isExpanded = true }
        }
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
