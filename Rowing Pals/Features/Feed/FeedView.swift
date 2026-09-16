//
//  FeedView.swift
//  Rowing Pals
//

import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()

    var body: some View {
        // The scroll view must be the direct descendant of the tab content for
        // TabView's `.tabBarMinimizeBehavior` to see it scroll — a NavigationStack
        // wrapper here breaks that and the bar never minimises.
        ScrollView {
            LazyVStack(spacing: 20) {
                Color.clear.frame(height: 96) // room for the glass header overlay

                if viewModel.posts.isEmpty && !viewModel.isLoading {
                    emptyState
                }

                ForEach(viewModel.posts) { post in
                    FeedCardView(
                        post: post,
                        monitorURL: post.primarySegment?.monitorPhotoPath.flatMap { viewModel.signedURL(forPath: $0) },
                        selfieURL: viewModel.signedURL(forPath: FeedViewModel.selfiePath(userId: post.userId, sessionId: post.id))
                    )
                    .padding(.horizontal, 12)
                    .task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(Tokens.Ink.primary)
                        .padding(.vertical, 20)
                }
            }
        }
        .background(Tokens.Base.ground)
        .overlay(alignment: .top) {
            feedHeader
        }
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.reload() }
    }

    private var feedHeader: some View {
        PillSegmentedControl(
            options: SocialScope.allCases.map(\.label),
            selection: scopeSelection
        )
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background {
            Tokens.Base.ground.opacity(0.7)
                .background(.ultraThinMaterial)
        }
    }

    private var scopeSelection: Binding<Int> {
        Binding(
            get: { viewModel.scope.rawValue },
            set: { viewModel.scope = SocialScope(rawValue: $0) ?? .global }
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            if let errorMessage = viewModel.errorMessage {
                Text("Couldn't load the feed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text(errorMessage)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(emptyStateTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text(emptyStateSubtitle)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    private var emptyStateTitle: String {
        switch viewModel.scope {
        case .following: "Nobody to show yet"
        case .myClub: "No posts from your club yet"
        case .global: "No posts yet"
        }
    }

    private var emptyStateSubtitle: String {
        switch viewModel.scope {
        case .following: "Follow some rowers to see their sessions here."
        case .myClub: "Be the first to post a session."
        case .global: "Be the first to post a session."
        }
    }
}

#Preview {
    FeedView()
}
