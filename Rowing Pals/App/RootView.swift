//
//  RootView.swift
//  Rowing Pals
//

import SwiftUI

/// The app shell. Redesigned 2026-09-17 (phase A) to match
/// docs/design/rowing-pals-redesign-handoff-v2.md §4 exactly: the bottom
/// nav is two separate floating glass shapes, not one bar — a
/// Feed/Rankings/Profile pill plus a standalone circular Log button — so
/// this hand-builds tab switching with a plain `ZStack` instead of a
/// native `TabView` (which can only float one unified bar). See
/// `FloatingTabBar` and `FloatingBarVisibility` for the bar itself and the
/// scroll-linked shrink/expand behaviour that replaces
/// `.tabBarMinimizeBehavior`.
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
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)

                FloatingTabBar(items: Self.items, selection: $selection) {
                    isShowingPostSheet = true
                }
                // Matches the prototype's own `bottom:max(14px,env(safe-area-inset-bottom))`
                // exactly — never less than 14pt, but never less than the
                // real home-indicator safe area either.
                .padding(.bottom, max(14, geometry.safeAreaInsets.bottom))
            }
        }
        .environment(barVisibility)
        .sheet(isPresented: $isShowingPostSheet) {
            PostSheetView()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .feed:
            FeedView()
        case .rankings:
            RankingsView()
        case .profile:
            ProfileView()
        }
    }
}

#Preview {
    RootView()
}
