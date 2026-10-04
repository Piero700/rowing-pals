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

    private let viewing: UUID?
    /// Goes up by one each time Profile is tapped while already selected (decision 27).
    private let reselects: Int
    @State private var viewModel: ProfileViewModel
    @State private var expandedTest: StandardTest?
    @State private var isShowingSettings = false
    @State private var isShowingAllPBs = false
    @State private var tab: Tab = .overview
    @Environment(\.navigate) private var navigate
    @Environment(\.dismiss) private var dismiss

    private static let overviewPBKeys = ["2k", "5k"]
    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(viewing: UUID? = nil, reselects: Int = 0) {
        self.viewing = viewing
        self.reselects = reselects
        _viewModel = State(initialValue: ProfileViewModel(userId: viewing))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                identity
                socialRow

                if isOtherRower {
                    otherRowerSections
                } else if viewModel.isLocked {
                    privateCard
                        .padding(.top, Tokens.Spacing.loose)
                } else {
                    statsCard
                    PillSegmentedControl(
                        options: Tab.allCases.map(\.label),
                        selection: Binding(get: { tab.rawValue }, set: { tab = Tab(rawValue: $0) ?? .overview })
                    )
                    .padding(.top, 11)

                    switch tab {
                    case .overview: overview
                    case .pbs: allPBs
                    case .posts: postsGrid
                    }
                }

                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
        }
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) { await viewModel.load() }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewing == nil {
                header
            } else {
                ScreenHeader(title: "Rower profile") { dismiss() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.load() }
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

    // MARK: - Header and identity

    private var header: some View {
        HStack(spacing: Tokens.Spacing.gap) {
            Text("Profile")
                .textStyle(Typography.largeTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            GlassIconButton(systemImage: "gearshape", accessibilityLabel: "Settings") {
                isShowingSettings = true
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, 14)
        .frame(minHeight: Tokens.Size.headerMinHeight)
        .background(Tokens.Base.ground)
    }

    /// Centred 76 pt avatar (with a 32 pt streak badge), name 23 bold, "Club · Level" 13 muted.
    private var identity: some View {
        VStack(spacing: 0) {
            AvatarPlaceholder(diameter: 76, streakDays: viewModel.streakDays, name: viewModel.displayName)
                .padding(.bottom, 10)
            Text(viewModel.displayName)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
                .multilineTextAlignment(.center)
            Text(identityMeta)
                .font(.system(size: 13))
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 4)
                .padding(.bottom, isOtherRower ? 0 : 8)
            if isOtherRower {
                // v3 §08: the club on one line, whether the profile is public on the next.
                Text(viewModel.isPrivateAccount ? "Private profile" : "Public profile")
                    .font(.system(size: 13))
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 11)
        .padding(.bottom, 14)
    }

    /// Your own profile: "Club · Level". Another rower's (v3 §08): the club alone.
    private var identityMeta: String {
        let club = viewModel.clubName ?? "No club"
        if isOtherRower { return club }
        let level = viewModel.categoryLabel.capitalized
        return level.isEmpty ? club : "\(club) · \(level)"
    }

    /// Someone else's profile, reached from a post, a list or a search.
    private var isOtherRower: Bool {
        viewing != nil && !viewModel.isOwnProfile
    }

    // MARK: - Social

    /// Centred Followers / Following counts (each opens its list), then Find rowers and — on
    /// your own profile, when someone is waiting — Follow requests. Hidden for a locked profile.
    @ViewBuilder
    private var socialRow: some View {
        if isOtherRower {
            // v3 §08: a full-width Follow / Following button under the identity.
            FollowButton(
                state: viewModel.followState,
                followsYou: viewModel.followsYou,
                isBusy: viewModel.isFollowBusy,
                variant: .fullWidth
            ) {
                Task { await viewModel.toggleFollow() }
            }
        }
        if !viewModel.isLocked, let userId = viewModel.profileUserId {
            HStack(spacing: 6) {
                countButton(value: viewModel.followerCount, label: "Followers") {
                    navigate(.people(.followers(userId)))
                }
                countButton(value: viewModel.followingCount, label: "Following") {
                    navigate(.people(.following(userId)))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Spacing.gap)
        }
        if viewModel.isOwnProfile {
            Button("Find rowers") { navigate(.people(.find)) }
                .buttonStyle(.rpText)
                .frame(maxWidth: .infinity)
            if viewModel.pendingRequestCount > 0 {
                Button {
                    navigate(.followRequests)
                } label: {
                    HStack {
                        Text("Follow requests · \(viewModel.pendingRequestCount)")
                            .tabularNumerals()
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.rpGlass)
                .padding(.bottom, Tokens.Spacing.loose)
            }
        }
    }

    private func countButton(value: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text(label)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minHeight: 48)
            .contentShape(Capsule())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel("\(value) \(label)")
    }

    /// Shown in place of every stat for a private account the viewer is not approved to see.
    private var privateCard: some View {
        VStack(spacing: Tokens.Spacing.gap) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Tokens.Ink.secondary)
            Text("This profile is private")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Tokens.Ink.primary)
            Text("Send a follow request to see their stats, personal bests, followers and following.")
                .textStyle(Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    // MARK: - Stats

    /// 4-up card: weekly volume, sessions, PBs, streak days — value 21 bold over a 10 pt label,
    /// thin dividers between columns.
    private var statsCard: some View {
        statsCard([
            (Self.compactMetres(currentWeekVolumeM), "weekly volume"),
            ("\(viewModel.seasonSessionCount)", "sessions"),
            ("\(pbCount)", "PBs"),
            ("\(viewModel.streakDays)", "streak days")
        ])
    }

    private func statsCard(_ stats: [(String, String)]) -> some View {
        HStack(spacing: 0) {
            ForEach(stats.indices, id: \.self) { index in
                VStack(spacing: 2) {
                    Text(stats[index].0)
                        .font(.system(size: 21, weight: .bold))
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(stats[index].1)
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                if index < stats.count - 1 {
                    Rectangle().fill(Tokens.Surface.line).frame(width: 1, height: 30)
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.loose)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private var currentWeekVolumeM: Int {
        viewModel.weeklyVolumes.first(where: \.isCurrentWeek)?.distanceM ?? 0
    }

    private var pbCount: Int {
        viewModel.pbTiles.filter(\.hasResult).count
    }

    /// "116.3k" — thousands of metres, as the v3 stats card writes it.
    private static func compactMetres(_ metres: Int) -> String {
        guard metres >= 1_000 else { return "\(metres)" }
        return String(format: "%.1fk", Double(metres) / 1_000)
    }

    // MARK: - Another rower (v3 §08)

    /// v3 §08 exactly (decision 22): this week's volume, two personal bests and their place
    /// in their own club — no tabs, chart, grid or posts. A private account you aren't
    /// approved for shows only the lock card.
    @ViewBuilder
    private var otherRowerSections: some View {
        if viewModel.isLocked {
            privateCard
                .padding(.top, Tokens.Spacing.loose)
        } else {
            sectionTitle("Volume · This week")
            statsCard([
                (Self.compactMetres(currentWeekVolumeM), "metres"),
                (Self.rankText(viewModel.clubRanks?.weeklyVolume), "volume ranking"),
                ("\(viewModel.weekSessionCount)", "sessions"),
                ("\(viewModel.streakDays)", "streak days")
            ])

            sectionTitle("Personal bests")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight), count: 2), spacing: Tokens.Spacing.tight) {
                ForEach(viewModel.pbTiles.filter { Self.rowerPBKeys.contains($0.test.key) }) { tile in
                    // Decision 21: their all-time best, not a season best.
                    PBTileView(tile: tile, label: tile.test.longTitle, footnote: "Personal best") { expandedTest = tile.test }
                }
            }

            // Decision 20: ranks within their own club — app-wide rankings were dropped (17).
            if viewModel.clubName != nil {
                sectionTitle("Club rankings")
                rankingsCard
            }
        }
    }

    /// Three columns — this week's volume, 2k, 5k — each "#n" over its label.
    private var rankingsCard: some View {
        let ranks: [(Int?, String)] = [
            (viewModel.clubRanks?.weeklyVolume, "weekly volume"),
            (viewModel.clubRanks?.twoK, "2k test"),
            (viewModel.clubRanks?.fiveK, "5k test")
        ]
        return HStack(spacing: 0) {
            ForEach(ranks.indices, id: \.self) { index in
                VStack(spacing: 2) {
                    Text(Self.rankText(ranks[index].0))
                        .textStyle(Typography.rankValue)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(ranks[index].1)
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                if index < ranks.count - 1 {
                    Rectangle().fill(Tokens.Surface.line).frame(width: 1, height: 30)
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.loose)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    /// v3 §08's two PB tiles.
    private static let rowerPBKeys = ["2k", "30min"]

    /// "#5", or a dash with nothing to rank.
    private static func rankText(_ rank: Int?) -> String {
        rank.map { "#\($0)" } ?? "—"
    }

    // MARK: - Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Top personal bests") {
                Button("View all ›") { isShowingAllPBs = true }
                    .buttonStyle(.rpText)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight), count: 2), spacing: Tokens.Spacing.tight) {
                ForEach(topPBTiles) { tile in
                    PBTileView(tile: tile) { expandedTest = tile.test }
                }
            }

            if viewModel.isOwnProfile {
                VStack(spacing: Tokens.Spacing.gap) {
                    EstimateCard(label: "2k · Estimated today")
                    EstimateCard(label: "5k · Estimated today")
                }
                .padding(.top, Tokens.Spacing.loose)
            }

            sectionHeader("Weekly volume") { chip("12 weeks") }
                .padding(.top, 4)
            WeeklyVolumeChart(weeks: viewModel.weeklyVolumes)
                .padding(.vertical, 18)
                .padding(.horizontal, Tokens.Spacing.card)
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }

            sectionHeader("Consistency") { chip("\(viewModel.activeDaysInGrid) active days") }
            ConsistencyCalendarView(days: viewModel.consistencyDays, footnote: streakFootnote)
                .padding(.vertical, 18)
                .padding(.horizontal, Tokens.Spacing.card)
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }

            if let latest = viewModel.latestSession {
                sectionTitle("Recent activity")
                recentActivity(latest)
            }

            if viewModel.isOwnProfile {
                clubEntry
            }
        }
    }

    /// The v2 prototype's club entry (decision 25): admins and up manage the club; members see
    /// Your crew; rowers without a club join or create one. A pending request shows beneath.
    private var clubEntry: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Club")
            Button(clubEntryTitle) {
                navigate(viewModel.clubRole?.canManageMembers == true ? .manageClub : .clubHub)
            }
            .buttonStyle(.rpGlass)
            if let pending = viewModel.pendingClubName {
                Text("Join request pending · \(pending)")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 2)
            }
            ForEach(viewModel.invitingClubNames, id: \.self) { club in
                Button {
                    navigate(.clubHub)
                } label: {
                    Text("\(club) invited you to join · View")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Accent.brand)
                        .frame(minHeight: Tokens.Size.minTap)
                }
                .buttonStyle(IconPressStyle())
                .padding(.horizontal, 2)
            }
        }
    }

    private var clubEntryTitle: String {
        switch viewModel.clubRole {
        case .none: "Join or create a club"
        case .member?: "Your club"
        default: "Manage your club"
        }
    }

    private var topPBTiles: [ProfileViewModel.PBTile] {
        viewModel.pbTiles.filter { Self.overviewPBKeys.contains($0.test.key) }
    }

    /// v3 streak footnote, carrying the rest-day allowance the old streak block showed.
    private var streakFootnote: String {
        let remaining = max(0, viewModel.restDaysAllowedPerWeek - viewModel.restDaysUsedThisWeek)
        let rest = "\(remaining) rest day\(remaining == 1 ? "" : "s") left this week"
        if viewModel.streakDays > 0 {
            return "\(viewModel.streakDays)-day current streak · \(rest)"
        }
        return "Post a workout to start a streak · \(rest)"
    }

    /// v3 section title: 12 pt heavy uppercase, muted, 20 top / 9 bottom.
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 2)
            .padding(.top, Tokens.Spacing.sectionTop)
            .padding(.bottom, Tokens.Spacing.sectionBottom)
            .accessibilityAddTraits(.isHeader)
    }

    /// A section title with something on the right (a chip, "View all"), both centred on one
    /// line, with the section spacing around the whole row.
    private func sectionHeader<Trailing: View>(_ text: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(text)
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 2)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing()
        }
        .padding(.top, Tokens.Spacing.sectionTop - 8)
        .padding(.bottom, Tokens.Spacing.sectionBottom - 4)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 8)
            .frame(minHeight: 27)
            .background(Capsule().fill(Tokens.Surface.raised))
    }

    /// Placeholder until the rower's own prediction algorithm is added (decision 2): the v3
    /// card, with no number invented.
    private func recentActivity(_ session: ProfileViewModel.ProfilePhoto) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.workoutLink, style: .continuous)
        return Button {
            navigate(.post(session.id))
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(session.workoutLabel ?? "Training") · \(session.distanceM.formattedMetres)")
                        .font(.system(size: 14, weight: .bold))
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                    Text("\(session.totalTimeMs.formattedDurationMs) · View workout")
                        .font(.system(size: 12))
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
            }
            .padding(Tokens.Spacing.card)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(shape.fill(Tokens.Surface.card))
            .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
            .contentShape(shape)
        }
        .buttonStyle(IconPressStyle())
    }

    // MARK: - PBs tab

    private var allPBs: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight), count: 2), spacing: Tokens.Spacing.tight) {
            ForEach(viewModel.pbTiles) { tile in
                PBTileView(tile: tile) { expandedTest = tile.test }
            }
        }
        .padding(.top, Tokens.Spacing.sectionTop)
    }

    // MARK: - Posts tab

    private var postsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
            ForEach(viewModel.photos) { photo in
                photoTile(photo)
                    .asButton { navigate(.post(photo.id)) }
            }
        }
        .padding(.top, Tokens.Spacing.sectionTop)
    }

    private func photoTile(_ photo: ProfileViewModel.ProfilePhoto) -> some View {
        CachedAsyncImage(url: viewModel.photoURL(for: photo.monitorPath)) {
            PhotoPlaceholder(cornerRadius: 12)
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(photo.distanceM.formattedMetres)
                .font(.system(size: 10, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .padding(6)
        }
        .accessibilityLabel("Workout, \(photo.distanceM.formattedMetres)")
    }
}

#Preview {
    ProfileView()
}
