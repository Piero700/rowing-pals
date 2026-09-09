//
//  RootView.swift
//  Rowing Pals
//

import SwiftUI

/// The app shell: five tabs in a floating, glass tab bar that shrinks on scroll
/// down and expands on scroll up. This is native `TabView` behaviour — see
/// `.tabBarMinimizeBehavior` below — not hand-built chrome.
struct RootView: View {
    private enum RootTab: Hashable {
        case feed, metres, post, tests, profile
    }

    @State private var selection: RootTab = .feed
    @State private var previousSelection: RootTab = .feed
    @State private var isShowingPostSheet = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Feed", systemImage: "list.bullet", value: RootTab.feed) {
                FeedView()
            }

            Tab("Metres", systemImage: "figure.rower", value: RootTab.metres) {
                MetresView()
            }

            Tab("Post", systemImage: "plus.circle.fill", value: RootTab.post) {
                Color.clear
            }

            Tab("Tests", systemImage: "stopwatch", value: RootTab.tests) {
                TestsView()
            }

            Tab("Profile", systemImage: "person.fill", value: RootTab.profile) {
                ProfileView()
            }
        }
        .tint(Tokens.Accent.signal)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selection) { _, newValue in
            if newValue == .post {
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
