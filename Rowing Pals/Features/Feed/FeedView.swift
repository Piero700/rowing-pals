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
    /// What opens over the feed: a workout, or a post's comments thread.
    private enum Cover: Identifiable {
        case post(UUID)
        case comments(UUID, subtitle: String, canComment: Bool)

        var id: String {
            switch self {
            case .post(let id): "post-\(id)"
            case .comments(let id, _, _): "comments-\(id)"
            }
        }
    }

    /// Goes up by one each time Feed is tapped while already selected.
    var reselects = 0

    @State private var viewModel = FeedViewModel()
    @State private var cover: Cover?
    /// The rower's boats for today's water sessions, or tomorrow's (decisions 67, 79).
    @State private var feedBoats = FeedBoatsModel()
    /// The club's announcements, folded to their headings until tapped (decision 75).
    @State private var announcements = FeedAnnouncementsModel()
    @State private var openAnnouncements: Set<UUID> = []
    @Environment(\.navigate) private var navigate
    @Environment(\.scenePhase) private var scenePhase

    /// Pull to refresh and tapping Feed again. Runs in its own task so the pull can't cancel it half
    /// way (a cancelled load used to empty the boat cards, user 2026-10-18).
    private func refreshAll() async {
        await Task {
            ViewerContext.shared.invalidate()
            async let boat: Void = feedBoats.load()
            async let notices: Void = announcements.load()
            await viewModel.reload()
            await boat
            await notices
        }.value
    }

    private func toggle(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            if openAnnouncements.contains(id) { openAnnouncements.remove(id) } else { openAnnouncements.insert(id) }
        }
    }

    var body: some View {
        // The scroll view stays the tab's root view so the floating bar can track it.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                PillSegmentedControl(options: ["Following", "Club"], selection: scopeSelection)

                Text(scopeCaption)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 2)
                    .padding(.vertical, Tokens.Spacing.loose)

                if !announcements.announcements.isEmpty {
                    VStack(spacing: Tokens.Spacing.tight) {
                        ForEach(announcements.announcements) { announcement in
                            FeedAnnouncementCard(
                                announcement: announcement,
                                meta: announcements.meta(announcement),
                                isExpanded: openAnnouncements.contains(announcement.id),
                                canEdit: announcements.canManage,
                                onToggle: { toggle(announcement.id) },
                                onEdit: { navigate(.editAnnouncement(announcement.id)) }
                            )
                        }
                    }
                    .padding(.bottom, Tokens.Spacing.loose)
                }

                ForEach(viewModel.todaysWorkouts) { today in
                    TodaysWorkoutCard(today: today) { navigate(.logWorkout(today.id)) }
                        .padding(.bottom, Tokens.Spacing.loose)
                }

                // Today's boats, then tomorrow's once today's are over (decision 79).
                ForEach(feedBoats.items) { item in
                    FeedBoatCard(boat: item.boat, session: item.session, names: feedBoats.names,
                                 coachName: item.coachName, mySeat: item.mySeat)
                        .padding(.bottom, Tokens.Spacing.loose)
                }


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
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) {
            await refreshAll()
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.loadInitial() }
        .task { await feedBoats.load() }
        .task { await announcements.load() }
        .onReceive(NotificationCenter.default.publisher(for: .announcementsChanged)) { _ in
            Task { await announcements.load() }
        }
        .refreshable {
            await refreshAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .boatsChanged)) { _ in
            Task { await feedBoats.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.clubChanged() }
            Task { await feedBoats.load() }
        }
        // A new post shows, and a workout it was for leaves the Feed (decision 57).
        // A post you deleted leaves the feed at once (decision 63).
        .onReceive(NotificationCenter.default.publisher(for: .sessionDeleted)) { note in
            guard let id = note.object as? UUID else { return }
            withAnimation { viewModel.posts.removeAll { $0.id == id } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionPosted)) { _ in
            Task { await viewModel.reload() }
        }
        // Back from the background, perhaps on a new day: yesterday's workouts go.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.refreshWorkouts() }
                Task { await feedBoats.load() }
                Task { await announcements.load() }
            }
        }
        .fullScreenCover(item: $cover) { cover in
            switch cover {
            case .post(let id):
                PostDetailView(sessionId: id) { count in
                    viewModel.setCommentCount(count, on: id)
                }
            case .comments(let id, let subtitle, let canComment):
                CommentsView(sessionId: id, subtitle: subtitle, canComment: canComment) { count in
                    viewModel.setCommentCount(count, on: id)
                }
            }
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
            GlassIconButton(icon: .search, accessibilityLabel: "Find rowers") {
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
                    onOpen: { cover = .post(post.id) },
                    onOpenComments: {
                        cover = .comments(
                            post.id,
                            subtitle: "\(post.author.displayName) · \(post.workoutLabel ?? "Training")",
                            canComment: !viewModel.readOnlyPostIds.contains(post.id)
                        )
                    },
                    onToggleReaction: { kind in
                        Task { await viewModel.toggleReaction(kind: kind, on: post.id) }
                    },
                    canInteract: !viewModel.readOnlyPostIds.contains(post.id)
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
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
            }
            Text(body)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
            if showsPostButton && viewModel.viewerIsRower {
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
