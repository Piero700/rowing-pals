//
//  RootView.swift
//  Rowing Pals
//

import SwiftUI

/// The app shell. Bottom nav rebuilt 2026-09-18 around a real reference:
/// the user supplied a screen recording of Instagram's own bar and asked
/// for that instead of the redesign prototype's two-separate-capsules
/// spec (docs/design/rowing-pals-redesign-handoff-v2.md §4) — one
/// unified floating pill holding every icon together, icon-only, sitting
/// close to the bottom. See `FloatingTabBar` for the bar itself.
///
/// Still hand-built tab switching rather than a native `TabView`, since
/// Log opens a sheet instead of actually becoming a selected tab (this
/// app's long-standing "Post sits outside tab selection" pattern) — see
/// `FloatingBarVisibility` for the scroll-linked shrink/expand behaviour
/// that replaces `.tabBarMinimizeBehavior`.
///
/// Two structural fixes from real-device feedback on the earlier version,
/// both still true here:
///
/// 1. All three real tabs are instantiated once, up front, and shown/hidden
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
///    pinned row) and composes hit-testing predictably. No extra minimum
///    bottom padding either — SwiftUI already keeps an `.overlay` clear of
///    the safe area on its own, which also sits the bar closer to the true
///    bottom edge, matching Instagram's own closeness.
struct RootView: View {
    private enum RootTab: Hashable {
        case feed, rankings, log, profile
    }

    @State private var selection: RootTab = .feed
    @State private var isShowingPostSheet = false
    @State private var barVisibility = FloatingBarVisibility()

    /// House/bar-chart/person — matches the prototype's actual inline SVG
    /// icon defs (`#home`/`#rank`/`#user`), confirmed against the
    /// prototype file directly. Log sits third, between Rankings and
    /// Profile, matching where Instagram places its own centre action.
    private static let items: [FloatingTabBar<RootTab>.Item] = [
        .init(tab: .feed, systemImage: "house.fill"),
        .init(tab: .rankings, systemImage: "chart.bar.fill"),
        .init(tab: .log, systemImage: "plus.circle.fill", isLog: true),
        .init(tab: .profile, systemImage: "person.fill")
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
