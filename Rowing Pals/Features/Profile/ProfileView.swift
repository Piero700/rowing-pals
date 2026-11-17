//
//  ProfileView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 06 — Profile, to v3 (`docs/design/v3/RP Screen.dc.html` §06): pinned "Profile" title
/// with a glass Settings button; centred 76 pt avatar, name and "Club · Level"; Followers and
/// Following counts; Find rowers; a 4-up stats card; Overview / PBs / Posts. Overview holds the
/// top two PBs, the estimate cards, the weekly volume chart, the consistency grid and the most
/// recent workout.
///
/// Another rower's profile (`viewing` set) follows v3 §08 exactly (decisions 20–22): "Rower
/// profile" header, identity, full-width Follow, counts, this week's volume, two personal bests
/// and their ranks within their own club. Only the lock card shows when their account is
/// private and not approved (phase E).
struct ProfileView: View {
    private enum Tab: Int, CaseIterable {
        case overview, pbs, posts
        var label: String {
            switch self {
            case .overview: "Overview"
            case .pbs: "PBs"
            case .posts: "Posts"
            }
        }
    }

    /// A distance Profile predicts, and what to call it.
    struct PredictedDistance: Identifiable, Hashable {
        let title: String
        let metres: Double
        var id: Double { metres }
    }

    /// Decision 31: the 2k and 5k cards.
    static let predictedDistances = [
        PredictedDistance(title: "2k", metres: 2000),
        PredictedDistance(title: "5k", metres: 5000),
    ]

    private let viewing: UUID?
    /// Goes up by one each time Profile is tapped while already selected (decision 27).
    private let reselects: Int
    @State private var viewModel: ProfileViewModel
    @State private var expandedTest: StandardTest?
    /// The prediction whose "How we got this" sheet is open (decision 31).
    @State private var explainedTarget: PredictedDistance?
    @State private var isShowingSettings = false
    @State private var isShowingAllPBs = false
    @State private var tab: Tab = .overview
    /// The post a press-and-hold on the Posts grid asked to delete (decision 63).
    @State private var postToDelete: UUID?
    @State private var deleteError: String?
    @Environment(\.dismiss) private var dismiss

    init(viewing: UUID? = nil, reselects: Int = 0) {
        self.viewing = viewing
        self.reselects = reselects
        _viewModel = State(initialValue: ProfileViewModel(userId: viewing))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileIdentity(viewModel: viewModel, isOtherRower: isOtherRower)
                ProfileSocialRow(viewModel: viewModel, isOtherRower: isOtherRower)

                if isOtherRower {
                    ProfileOtherRowerSections(viewModel: viewModel) { expandedTest = $0 }
                } else if viewModel.isLocked {
                    ProfilePrivateCard()
                        .padding(.top, Tokens.Spacing.loose)
                } else {
                    ProfileStatsCard(stats: [
                        .init(value: ProfileStatsCard.compactMetres(currentWeekVolumeM), label: "weekly volume"),
                        .init(value: "\(viewModel.seasonSessionCount)", label: "sessions"),
                        .init(value: "\(pbCount)", label: "PBs"),
                        .init(value: "\(viewModel.streakDays)", label: "streak days")
                    ])
                    PillSegmentedControl(
                        options: Tab.allCases.map(\.label),
                        selection: Binding(get: { tab.rawValue }, set: { tab = Tab(rawValue: $0) ?? .overview })
                    )
                    .padding(.top, Tokens.Spacing.loose)

                    switch tab {
                    case .overview:
                        ProfileOverview(
                            viewModel: viewModel,
                            onOpenTest: { expandedTest = $0 },
                            onShowAllPBs: { isShowingAllPBs = true },
                            onExplain: { explainedTarget = $0 }
                        )
                    case .pbs:
                        ProfilePBGrid(tiles: viewModel.pbTiles) { expandedTest = $0 }
                    case .posts:
                        ProfilePostsGrid(viewModel: viewModel) { postToDelete = $0 }
                    }
                }

                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
        }
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) { ViewerContext.shared.invalidate(); await viewModel.load() }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewing == nil {
                ProfileHeaderBar { isShowingSettings = true }
            } else {
                ScreenHeader(title: "Rower profile") { dismiss() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.load() }
        .refreshable { ViewerContext.shared.invalidate(); await viewModel.load() }
        // A post deleted here or on its own page leaves the grid and the totals (decision 63).
        .onReceive(NotificationCenter.default.publisher(for: .sessionDeleted)) { _ in
            Task { await viewModel.load() }
        }
        .alert("Delete this post?", isPresented: Binding(
            get: { postToDelete != nil },
            set: { if !$0 { postToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { postToDelete = nil }
            Button("Delete", role: .destructive) {
                guard let id = postToDelete else { return }
                postToDelete = nil
                Task {
                    do { try await SessionService.delete(id) } catch { deleteError = error.localizedDescription }
                }
            }
        } message: {
            Text(SessionService.deleteWarning)
        }
        .alert("Couldn't delete the post", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.load() }
        }
        .sheet(item: $explainedTarget) { target in
            PredictionDetailView(title: target.title, prediction: viewModel.predictions[target.metres])
        }
        .fullScreenCover(item: $expandedTest) { test in
            PBHistoryView(test: test, userId: viewing)
        }
        .fullScreenCover(isPresented: $isShowingAllPBs) {
            AllPersonalBestsView(tiles: viewModel.pbTiles)
        }
        .sheet(isPresented: $isShowingSettings, onDismiss: { Task { await viewModel.load() } }) {
            SettingsView()
        }
    }

    // MARK: - Figures

    /// Someone else's profile, reached from a post, a list or a search.
    private var isOtherRower: Bool {
        viewing != nil && !viewModel.isOwnProfile
    }

    private var currentWeekVolumeM: Int {
        viewModel.weeklyVolumes.first(where: \.isCurrentWeek)?.distanceM ?? 0
    }

    private var pbCount: Int {
        viewModel.pbTiles.filter(\.hasResult).count
    }
}

#Preview {
    ProfileView()
}
