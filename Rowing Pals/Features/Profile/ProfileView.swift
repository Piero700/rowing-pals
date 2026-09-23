//
//  ProfileView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 7 — profile. Redesign phase C
/// (docs/design/rowing-pals-redesign-handoff-v2.md §2 Screen 06, §3):
/// header, a 4-up stats row (weekly volume/sessions/PBs/streak, replacing
/// the old 3-up season strip), the existing streak-and-rest-pips block
/// (kept — genuinely useful info the redesign doesn't ask to remove, not
/// re-described in the prototype but not contradicted by it either),
/// then an Overview/PBs/Posts toggle. Overview repositions the existing
/// weekly volume chart and consistency calendar (task 15) above the old
/// "Recent activity" position, plus the top two PB cards (2k, 5k); PBs
/// shows the full board; Posts shows the photo grid.
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

    @State private var viewModel = ProfileViewModel()
    @State private var expandedTest: StandardTest?
    @State private var isShowingSettings = false
    @State private var tab: Tab = .overview

    private static let overviewPBKeys = ["2k", "5k"]

    var body: some View {
        // Direct ScrollView child, same constraint as FeedView — see its comment.
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statsRow
                streakBlock

                PillSegmentedControl(
                    options: Tab.allCases.map(\.label),
                    selection: Binding(get: { tab.rawValue }, set: { tab = Tab(rawValue: $0) ?? .overview })
                )

                switch tab {
                case .overview: overviewContent
                case .pbs: pbGrid
                case .posts: postsGrid
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 14)
        }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .fullScreenCover(item: $expandedTest) { test in
            PBHistoryView(test: test)
        }
        .sheet(isPresented: $isShowingSettings, onDismiss: { Task { await viewModel.load() } }) {
            SettingsView()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AvatarPlaceholder(diameter: 52, streakDays: viewModel.streakDays)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(viewModel.displayName)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                    if !viewModel.categoryLabel.isEmpty {
                        Text(viewModel.categoryLabel)
                            .textStyle(Typography.label)
                            .textCase(nil)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Tokens.Ink.primary.opacity(0.12))
                            }
                    }
                }
                if let clubName = viewModel.clubName {
                    Text(clubName)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            Spacer()
            // Opens SettingsView (task 17: support contact + terms only —
            // task 18 adds edit-profile, novice/senior, weekly target,
            // sign out and Delete Account to the same screen).
            Button {
                isShowingSettings = true
            } label: {
                Text("Edit")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Tokens.Ink.primary.opacity(0.09))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    /// Weekly volume / sessions / PBs / streak — the redesign's 4-up stats
    /// card (§2 Screen 06), replacing the old 3-up season strip (season
    /// total distance / season sessions / longest streak, still available
    /// via the weekly volume chart and streakBlock below, just not
    /// duplicated up here). "Sessions" reads the season total, not a
    /// weekly count — the app doesn't track a per-week session count
    /// separately from per-week distance, and re-deriving one wasn't
    /// worth a new query for a number the weekly volume chart already
    /// contextualises properly just below.
    private var statsRow: some View {
        HStack {
            StatColumn(label: "WEEK'S METRES", value: currentWeekVolumeM.formattedMetres, alignment: .center)
                .frame(maxWidth: .infinity)
            StatColumn(label: "SESSIONS", value: "\(viewModel.seasonSessionCount)", alignment: .center)
                .frame(maxWidth: .infinity)
            StatColumn(label: "PBS", value: "\(pbCount)", alignment: .center)
                .frame(maxWidth: .infinity)
            StatColumn(label: "STREAK", value: "\(viewModel.streakDays)", alignment: .center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.07))
        }
    }

    private var currentWeekVolumeM: Int {
        viewModel.weeklyVolumes.first(where: \.isCurrentWeek)?.distanceM ?? 0
    }

    private var pbCount: Int {
        viewModel.pbTiles.filter(\.hasResult).count
    }

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(viewModel.streakDays)")
                    .font(.system(size: 40, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("day streak")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            // Filled pips are spent rest days, hollow ones remain — neutral
            // information either way, never red or a warning (CLAUDE.md /
            // design brief: a missed day covered by a rest day is not a
            // failure state).
            HStack(spacing: 6) {
                ForEach(0..<viewModel.restDaysAllowedPerWeek, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.restDaysUsedThisWeek ? Tokens.Ink.primary.opacity(0.45) : Color.clear)
                        .overlay {
                            Circle().strokeBorder(Tokens.Ink.primary.opacity(0.35), lineWidth: 1.5)
                        }
                        .frame(width: 9, height: 9)
                }
                Text(restDaysCaption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(16)
        .glassSurface(cornerRadius: 22)
    }

    private var restDaysCaption: String {
        let remaining = max(0, viewModel.restDaysAllowedPerWeek - viewModel.restDaysUsedThisWeek)
        return "\(remaining) rest day\(remaining == 1 ? "" : "s") left this week"
    }

    // MARK: - Overview tab

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionLabel("WEEKLY VOLUME")
            WeeklyVolumeChart(weeks: viewModel.weeklyVolumes, targetM: viewModel.weeklyTargetM)
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Tokens.Ink.primary.opacity(0.05))
                }

            sectionLabel("CONSISTENCY")
            ConsistencyCalendarView(days: viewModel.consistencyDays)
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Tokens.Ink.primary.opacity(0.05))
                }

            if !topPBTiles.isEmpty {
                HStack {
                    sectionLabel("PERSONAL BESTS")
                    Spacer()
                    // Redesign phase D — the handoff's "All personal bests"
                    // screen (§2 Screen 11) would just be a near-duplicate
                    // of the PBs tab below, which already shows every test
                    // in a flat grid tappable into PB history. Rather than
                    // build a second near-identical screen, "View all"
                    // switches straight to that existing tab.
                    Button("View all") { tab = .pbs }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Tokens.Accent.brand)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 2), spacing: 9) {
                    ForEach(topPBTiles) { tile in
                        pbTile(tile)
                            .onTapGesture {
                                guard tile.hasResult else { return }
                                expandedTest = tile.test
                            }
                    }
                }
            }
        }
    }

    /// 2k and 5k specifically — the redesign's own choice of "top" bests
    /// (§2 Screen 06), not just "however many fit."
    private var topPBTiles: [ProfileViewModel.PBTile] {
        viewModel.pbTiles.filter { Self.overviewPBKeys.contains($0.test.key) }
    }

    // MARK: - PBs tab

    private var pbGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
            ForEach(viewModel.pbTiles) { tile in
                pbTile(tile)
                    .onTapGesture {
                        guard tile.hasResult else { return }
                        expandedTest = tile.test
                    }
            }
        }
    }

    // MARK: - Posts tab

    private var postsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
            ForEach(viewModel.photos) { photo in
                photoTile(photo)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.label)
            .foregroundStyle(Tokens.Ink.secondary)
    }

    private func pbTile(_ tile: ProfileViewModel.PBTile) -> some View {
        Group {
            if tile.hasResult {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tile.test.label.uppercased())
                        .textStyle(Typography.label)
                        .foregroundStyle(Tokens.Ink.secondary)
                    Text(tile.displayValue ?? "—")
                        .font(.system(size: 19, weight: .bold))
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                    if let split = tile.splitDisplay {
                        Text(split)
                            .font(.system(size: 11.5))
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        if tile.isRecentPB {
                            Circle().fill(Tokens.Accent.records).frame(width: 5, height: 5)
                        }
                        Text(tile.dateDisplay ?? "")
                            .font(.system(size: 10.5))
                            .tabularNumerals()
                            .foregroundStyle(tile.isRecentPB ? Tokens.Accent.records : Tokens.Ink.secondary.opacity(0.7))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(minHeight: 96, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(tile.isRecentPB ? Tokens.Accent.records.opacity(0.09) : Tokens.Ink.primary.opacity(0.07))
                }
                .overlay {
                    if tile.isRecentPB {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Tokens.Accent.records.opacity(0.3), lineWidth: 1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tile.test.label.uppercased())
                        .textStyle(Typography.label)
                        .foregroundStyle(Tokens.Ink.secondary.opacity(0.7))
                    Text("—")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Tokens.Ink.secondary.opacity(0.5))
                    Spacer(minLength: 0)
                    Text("Have a crack")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Tokens.Ink.secondary.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(minHeight: 96, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Tokens.Ink.primary.opacity(0.14), lineWidth: 1.5)
                }
            }
        }
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
    }
}

#Preview {
    ProfileView()
}
