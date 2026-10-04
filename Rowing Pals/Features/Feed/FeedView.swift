//
//  FeedView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 02 — Activity feed, "Your crew" (docs/design/rowing-pals-v3-spec.md; exact values
/// from `docs/design/v3/RP Screen.dc.html` §02): a large-title header with a glass search
/// button, the Following / Club control with a caption naming the scope, and v3 post cards.
/// Tapping Feed in the tab bar while the feed is showing scrolls to the top and refreshes.
struct FeedView: View {
    /// `.fullScreenCover(item:)` requires `Identifiable` — `UUID` alone doesn't conform.
    private struct SelectedPost: Identifiable {
        let id: UUID
    }

    /// Goes up by one each time Feed is tapped while already selected.
    var reselects = 0

    @State private var viewModel = FeedViewModel()
    @State private var selectedPost: SelectedPost?
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// A tab-tap refresh is running; pull to refresh shows its own spinner.
    @State private var isRefreshingFromTab = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.navigate) private var navigate

    var body: some View {
        // The scroll view stays the tab's root view so the floating bar can track it.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if isRefreshingFromTab {
                    ProgressView()
                        .tint(Tokens.Ink.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Tokens.Spacing.loose)
                }

                PillSegmentedControl(options: ["Following", "Club"], selection: scopeSelection)

                Text(scopeCaption)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 2)
                    .padding(.vertical, Tokens.Spacing.loose)

                content

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(Tokens.Ink.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }

                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
        }
        .scrollPosition($scrollPosition)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.reload() }
        .onChange(of: reselects) { scrollToTopAndRefresh() }
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.clubChanged() }
        }
        .fullScreenCover(item: $selectedPost) { post in
            PostDetailView(sessionId: post.id)
        }
    }

    private func scrollToTopAndRefresh() {
        if reduceMotion {
            scrollPosition.scrollTo(edge: .top)
        } else {
            withAnimation(Tokens.Motion.scrollToTop) { scrollPosition.scrollTo(edge: .top) }
        }
        guard !isRefreshingFromTab else { return }
        isRefreshingFromTab = true
        Task {
            await viewModel.reload()
            isRefreshingFromTab = false
        }
    }

    // MARK: - Header

    /// Large title left, 44 pt glass search button right; min height 61, padding 8 / 18 / 14.
    private var header: some View {
        HStack(spacing: Tokens.Spacing.gap) {
            Text("Your crew")
                .textStyle(Typography.largeTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            GlassIconButton(systemImage: "magnifyingglass", accessibilityLabel: "Find rowers") {
                navigate(.people(.find))
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, 14)
        .frame(minHeight: Tokens.Size.headerMinHeight)
        .background(Tokens.Base.ground)
    }

    private var scopeSelection: Binding<Int> {
        Binding(
            get: { viewModel.scope.rawValue },
            set: { viewModel.scope = SocialScope(rawValue: $0) ?? .myClub }
        )
    }

    /// v3: "You and people you follow"; on Club, the club's name, or a prompt with no club.
    private var scopeCaption: String {
        switch viewModel.scope {
        case .following: "You and people you follow"
        case .myClub: viewModel.viewerClubName ?? "Join a club to see your crew"
        }
    }

    // MARK: - Posts

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
            messageCard(title: "Couldn't load the feed", body: errorMessage, showsPostButton: false)
        } else if viewModel.scope == .myClub, viewModel.viewerClubName == nil, !viewModel.isLoading {
            if let pending = viewModel.pendingClubName {
                messageCard(
                    title: "Request sent to \(pending)",
                    body: "Your crew's workouts appear here as soon as an admin accepts you.",
                    showsPostButton: false
                )
            } else {
                messageCard(title: "You're not in a club", body: "Find your crew to see their workouts here.", showsPostButton: false, showsFindClub: true)
            }
        } else if viewModel.posts.isEmpty, !viewModel.isLoading {
            messageCard(
                title: "Your crew starts here",
                body: viewModel.scope == .myClub
                    ? "No workouts in this club yet."
                    : "No workouts from you or people you follow yet.",
                showsPostButton: true
            )
        } else {
            ForEach(viewModel.posts) { post in
                FeedCardView(
                    post: post,
                    photoURL: { viewModel.signedURL(forPath: $0) },
                    selfieURL: viewModel.signedURL(forPath: FeedViewModel.selfiePath(userId: post.userId, sessionId: post.id)),
                    streakDays: viewModel.streakDays(forAuthor: post.userId),
                    reactions: viewModel.reactionSummaries(for: post),
                    onOpen: { selectedPost = SelectedPost(id: post.id) },
                    onToggleReaction: { kind in
                        Task { await viewModel.toggleReaction(kind: kind, on: post.id) }
                    }
                )
                .padding(.bottom, Tokens.Spacing.loose)
                .task { await viewModel.loadMoreIfNeeded(currentPost: post) }
            }
        }
    }

    /// The v3 empty-state card: card fill, 1 pt edge, radius 30, padding 15.
    private func messageCard(title: String?, body: String, showsPostButton: Bool, showsFindClub: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.gap) {
            if let title {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
            }
            Text(body)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
            if showsPostButton {
                Button("Post a workout") { navigate(.log) }
                    .buttonStyle(.rpPrimary)
                    .padding(.top, 4)
            }
            if showsFindClub {
                Button("Find a club") { navigate(.findClub) }
                    .buttonStyle(.rpPrimary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.card)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).fill(Tokens.Surface.card)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1)
        }
    }
}

#Preview {
    FeedView()
}
