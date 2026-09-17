//
//  RootView.swift
//  Rowing Pals
//

import SwiftUI

/// The app shell: four tabs in a floating, glass tab bar that shrinks on scroll
/// down and expands on scroll up. This is native `TabView` behaviour — see
/// `.tabBarMinimizeBehavior` below — not hand-built chrome.
///
/// Redesigned 2026-09-17 (phase A): Metres and Tests merged into one
/// Rankings tab (`RankingsView`), and Post renamed Log to match the new
/// design's language. The target look is two visually separate floating
/// glass capsules (a Feed/Rankings/Profile pill + a standalone circular Log
/// button) — see docs/design/rowing-pals-redesign-handoff-v2.md §4. Kept
/// as one native `TabView` here instead: splitting it into two custom
/// floating elements would mean hand-building the minimize-on-scroll
/// behaviour this modifier already gives for free, for a purely visual
/// difference. Flagged as a follow-up polish item, not done now.
struct RootView: View {
    private enum RootTab: Hashable {
        case feed, rankings, log, profile
    }

    @State private var selection: RootTab = .feed
    @State private var previousSelection: RootTab = .feed
    @State private var isShowingPostSheet = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Feed", systemImage: "list.bullet", value: RootTab.feed) {
                FeedView()
            }

            Tab("Rankings", systemImage: "trophy.fill", value: RootTab.rankings) {
                RankingsView()
            }

            Tab("Log", systemImage: "plus.circle.fill", value: RootTab.log) {
                Color.clear
            }

            Tab("Profile", systemImage: "person.fill", value: RootTab.profile) {
                ProfileView()
            }
        }
        .tint(Tokens.Accent.brand)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selection) { _, newValue in
            if newValue == .log {
                selection = previousSelection
                isShowingPostSheet = true
            } else {
                previousSelection = newValue
            }
        }
        .sheet(isPresented: $isShowingPostSheet) {
            PostSheetView()
        }
    }
}

#Preview {
    RootView()
}
