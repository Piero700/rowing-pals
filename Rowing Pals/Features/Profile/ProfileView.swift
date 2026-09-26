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
/// Another rower's profile (`viewing` set) uses the same layout, titled "Rower profile", with a
/// follow button, and shows only the lock card when their account is private and not approved
/// (phase E).
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
    @State private var viewModel: ProfileViewModel
    @State private var expandedTest: StandardTest?
    @State private var isShowingSettings = false
    @State private var tab: Tab = .overview
    @Environment(\.navigate) private var navigate

    private static let overviewPBKeys = ["2k", "5k"]
    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(viewing: UUID? = nil) {
        self.viewing = viewing
        _viewModel = State(initialValue: ProfileViewModel(userId: viewing))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                identity
                socialRow

                if viewModel.isLocked {
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.isOwnProfile && viewing == nil { header }
        }
        .navigationTitle(viewing == nil ? "" : "Rower profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .fullScreenCover(item: $expandedTest) { test in
            PBHistoryView(test: test, userId: viewing)
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
                .padding(.bottom, 8)
            if !viewModel.isOwnProfile {
                FollowButton(
                    state: viewModel.followState,
                    followsYou: viewModel.followsYou,
                    isBusy: viewModel.isFollowBusy
                ) {
                    Task { await viewModel.toggleFollow() }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 11)
        .padding(.bottom, 14)
    }

    private var identityMeta: String {
        let club = viewModel.clubName ?? "No club"
        let level = viewModel.categoryLabel.capitalized
        var parts = [club]
        if !level.isEmpty { parts.append(level) }
        if !viewModel.isOwnProfile { parts.append(viewModel.isPrivateAccount ? "Private profile" : "Public profile") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Social

    /// Centred Followers / Following counts (each opens its list), then Find rowers and — on
    /// your own profile, when someone is waiting — Follow requests. Hidden for a locked profile.
    @ViewBuilder
    private var socialRow: some View {
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
        let stats: [(String, String)] = [
            (Self.compactMetres(currentWeekVolumeM), "weekly volume"),
            ("\(viewModel.seasonSessionCount)", "sessions"),
            ("\(pbCount)", "PBs"),
            ("\(viewModel.streakDays)", "streak days")
        ]
        return HStack(spacing: 0) {
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

    // MARK: - Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Top personal bests") {
                Button("View all ›") { tab = .pbs }
                    .buttonStyle(.rpText)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight), count: 2), spacing: Tokens.Spacing.tight) {
                ForEach(topPBTiles) { tile in
                    pbTile(tile)
                }
            }

            if viewModel.isOwnProfile {
                VStack(spacing: Tokens.Spacing.gap) {
                    estimateCard(label: "2k · Estimated today")
                    estimateCard(label: "5k · Estimated today")
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
    private func estimateCard(label: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.estimate, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer()
                Image(systemName: "info.circle")
                    .foregroundStyle(Tokens.Accent.records)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
            }
            Text("—")
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(Tokens.Accent.records)
            Text("Your estimate will appear here once the prediction algorithm is added.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.vertical, 6)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(shape.fill(Tokens.Accent.recordsSoft))
        .overlay { shape.strokeBorder(Tokens.Accent.records.opacity(0.3), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

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
                pbTile(tile)
            }
        }
        .padding(.top, Tokens.Spacing.sectionTop)
    }

    /// v3 PB tile: card fill, 1 pt line, radius 24, min height 90 — label, value in the records
    /// colour, "View PB history ›". Empty tests invite a first attempt.
    private func pbTile(_ tile: ProfileViewModel.PBTile) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Text(tile.test.label.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Tokens.Ink.secondary)
            Text(tile.displayValue ?? "—")
                .font(.system(size: 17, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(tile.hasResult ? Tokens.Accent.records : Tokens.Ink.secondary)
                .padding(.top, 5)
                .padding(.bottom, 2)
            Text(tile.hasResult ? "View PB history ›" : "No result yet")
                .font(.system(size: 12))
                .foregroundStyle(Tokens.Ink.faint)
        }
        .padding(.vertical, 13)
        .padding(.leading, 13)
        .padding(.trailing, 24)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if tile.hasResult {
                Text("›")
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.top, 12)
                    .padding(.trailing, 11)
            }
        }
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
        .asButton {
            guard tile.hasResult else { return }
            expandedTest = tile.test
        }
        .accessibilityLabel("\(tile.test.label) personal best, \(tile.displayValue ?? "none")")
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
