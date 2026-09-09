//
//  FeedView.swift
//  Rowing Pals
//

import SwiftUI

struct FeedView: View {
    @State private var scopeSelection = 0
    @State private var selectedSession: MockFeedSession?

    private static let sessions = [
        MockFeedSession.steadyState,
        MockFeedSession.personalBest,
        MockFeedSession.waterOuting
    ]

    var body: some View {
        // The scroll view must be the direct descendant of the tab content for
        // TabView's `.tabBarMinimizeBehavior` to see it scroll — a NavigationStack
        // wrapper here breaks that and the bar never minimises.
        ScrollView {
            LazyVStack(spacing: 20) {
                Color.clear.frame(height: 96) // room for the glass header overlay

                ForEach(Self.sessions) { session in
                    SessionCardView(session: session)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedSession = session }
                }
            }
        }
        .background(Tokens.Base.ground)
        .overlay(alignment: .top) {
            feedHeader
        }
        .fullScreenCover(item: $selectedSession) { session in
            PostDetailView(session: session)
        }
    }

    private var feedHeader: some View {
        PillSegmentedControl(
            options: ["Following", "My Club", "Global"],
            selection: $scopeSelection
        )
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background {
            Tokens.Base.ground.opacity(0.7)
                .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    FeedView()
}
