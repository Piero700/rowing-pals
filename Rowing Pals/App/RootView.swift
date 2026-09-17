//
//  RootView.swift
//  Rowing Pals
//

import SwiftUI

/// The app shell. Redesigned 2026-09-17 (phase A) to match
/// docs/design/rowing-pals-redesign-handoff-v2.md §4: the bottom nav is
/// two separate floating glass shapes, not one bar — a
/// Feed/Rankings/Profile pill plus a standalone circular Log button — so
/// this hand-builds tab switching instead of a native `TabView` (which can
/// only float one unified bar). See `FloatingTabBar` and
/// `FloatingBarVisibility` for the bar itself and the scroll-linked
/// behaviour that replaces `.tabBarMinimizeBehavior`.
///
/// Real-device feedback (2026-09-17) fixed two structural issues here,
/// not just tuning:
///
/// 1. All three tabs are instantiated once, up front, and shown/hidden
///    with opacity + `allowsHitTesting` — **not** a `switch` that creates
///    a fresh view every time you change tabs. A `switch`-built view loses
///    identity on every switch: a brand-new `FeedViewModel` means a reset
///    scroll position and a full reload each time you come back to a tab,
///    which is exactly what read as "can't smoothly move between tabs" —
///    native `TabView` keeps every tab alive for this reason, and losing
///    that was a real regression, not a preference.
/// 2. `FloatingTabBar` sits in `content`'s own `.overlay(alignment: .bottom)`
///    rather than a sibling in a bespoke `ZStack` inside a `GeometryReader`
///    — `.overlay` is the pattern already proven elsewhere in this codebase
///    for floating UI on top of a `ScrollView` (e.g. `MetresLeaderboardView`'s
///    pinned row) and composes hit-testing predictably; taps meant for the
///    bar were occasionally reaching a feed card underneath instead with
///    the old structure. No extra minimum bottom padding either — SwiftUI
///    already keeps an `.overlay` clear of the safe area on its own, which
///    also happens to sit the bar closer to the true bottom edge, matching
///    the Instagram-style closeness asked for.
struct RootView: View {
    private enum RootTab: Hashable {
        case feed, rankings, profile
    }

    @State private var selection: RootTab = .feed
    @State private var isShowingPostSheet = false
    @State private var barVisibility = FloatingBarVisibility()

    /// House/bar-chart/person — matches the prototype's actual inline SVG
    /// icon defs (`#home`/`#rank`/`#user`), not a guess at "something
    /// feed-like" — confirmed against the prototype file directly, not
    /// just the earlier design summary.
    private static let items: [FloatingTabBar<RootTab>.Item] = [
        .init(tab: .feed, label: "Feed", systemImage: "house.fill"),
        .init(tab: .rankings, label: "Rankings", systemImage: "chart.bar.fill"),
        .init(tab: .profile, label: "Profile", systemImage: "person.fill")
    ]

    var body: some View {
        content
            .overlay(alignment: .bottom) {
                FloatingTabBar(items: Self.items, selection: $selection) {
                    isShowingPostSheet = true
                }
            }
            .environment(barVisibility)
            .sheet(isPresented: $isShowingPostSheet) {
                PostSheetView()
            }
    }

    /// All three live simultaneously — see the doc comment above for why.
    private var content: some View {
        ZStack {
            tab(.feed) { FeedView() }
            tab(.rankings) { RankingsView() }
            tab(.profile) { ProfileView() }
        }
    }

    private func tab(_ tab: RootTab, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(selection == tab ? 1 : 0)
            .allowsHitTesting(selection == tab)
    }
}

#Preview {
    RootView()
}
