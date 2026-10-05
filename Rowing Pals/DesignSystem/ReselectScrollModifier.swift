//
//  ReselectScrollModifier.swift
//  Rowing Pals
//

import SwiftUI

/// Tapping the tab you're already on scrolls that tab's list to the top, then refreshes it, with
/// a spinner under the header while it reloads (decision 27).
///
/// The order matters. Starting the reload mid-scroll put the spinner above what was on screen;
/// on a phone iOS held the visible content in place, which cancelled the scroll and read to the
/// floating bar as scrolling down, hiding it until the reload finished (user, 2026-10-04). So
/// the scroll finishes first, and the spinner only appears when the list is at the top, where
/// adding it can't move anything. "Finishes" is the scroll view reporting the top: an animation
/// completion fires as soon as the scroll starts, since the scroll view runs that animation itself.
private struct ReselectScrollModifier: ViewModifier {
    /// If a finger stops the scroll before the top, refresh anyway (without the spinner) after this.
    private static let topTimeout = Duration.seconds(1)

    let reselects: Int
    let refresh: () async -> Void

    @State private var position = ScrollPosition(edge: .top)
    @State private var isAtTop = true
    @State private var isRefreshing = false
    @State private var isAwaitingTop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            // A Bool, not the offset, so the screen only redraws when it reaches or leaves the top.
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top <= 1
            } action: { _, atTop in
                isAtTop = atTop
                if atTop, isAwaitingTop {
                    isAwaitingTop = false
                    startRefresh()
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if isRefreshing {
                    ProgressView()
                        .tint(Tokens.Ink.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Tokens.Spacing.loose)
                        .background(Tokens.Base.ground)
                }
            }
            .onChange(of: reselects) { scrollToTopThenRefresh() }
    }

    private func scrollToTopThenRefresh() {
        guard !isAtTop else {
            startRefresh()
            return
        }
        isAwaitingTop = true
        if reduceMotion {
            position.scrollTo(edge: .top)
        } else {
            withAnimation(Tokens.Motion.scrollToTop) { position.scrollTo(edge: .top) }
        }
        Task {
            try? await Task.sleep(for: Self.topTimeout)
            guard isAwaitingTop else { return }
            isAwaitingTop = false
            startRefresh()
        }
    }

    private func startRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = isAtTop
        Task {
            await refresh()
            isRefreshing = false
        }
    }
}

extension View {
    /// Apply to a tab's root `ScrollView`. `reselects` goes up by one each time the tab is tapped
    /// while already showing; the list then scrolls to the top and `refresh` runs.
    func scrollsToTopOnReselect(_ reselects: Int, refresh: @escaping () async -> Void) -> some View {
        modifier(ReselectScrollModifier(reselects: reselects, refresh: refresh))
    }
}
