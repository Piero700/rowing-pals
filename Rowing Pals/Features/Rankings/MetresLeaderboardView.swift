//
//  MetresLeaderboardView.swift
//  Rowing Pals
//

import SwiftUI

/// Rankings → Volume, to v4 (`docs/design/v4/RankingsVolume.dc.html`): mode control, Week /
/// Month / Year, the lilac rank-hero card ("Weekly volume · You · #2", the gap to the next place,
/// the group leader), one filters pill naming the group ("Senior men · My club · Erg + water",
/// decision 37) with the rower count, and one leaderboard card of 72 pt rows (#1 in gold with ♛
/// and a gold edge bar, your row tinted brand). Opens on the viewer's own group; scope stays My
/// club / Following (decision 17). Distances follow the km toggle (decision 3).
struct MetresLeaderboardView: View {
    @Binding var mode: RankingsMode
    /// Goes up by one each time Rankings is tapped while already selected (decision 27).
    var reselects = 0

    @State private var viewModel = MetresLeaderboardViewModel()
    @State private var isOwnRowVisible = true
    @State private var isShowingFilters = false
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres
    @Environment(\.navigate) private var navigate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RankingsHeader(mode: $mode)

                PillSegmentedControl(
                    options: MetresLeaderboardViewModel.Period.allCases.map(\.label),
                    selection: periodSelection
                )
                .padding(.top, Tokens.Spacing.loose)

                rankHeroCard
                    .padding(.top, 13)

                HStack(spacing: Tokens.Spacing.gap) {
                    RankingsFiltersPill(text: filterSummary) { isShowingFilters = true }
                    Spacer(minLength: 0)
                    Text(rowerCount)
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .padding(.top, Tokens.Spacing.loose + 4)
                .padding(.bottom, Tokens.Spacing.loose)

                if viewModel.rankedRows.isEmpty {
                    emptyCard
                } else {
                    leaderboard
                }

                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
        }
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) { await viewModel.reload() }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .bottom) {
            if !isOwnRowVisible, let ownRow = viewModel.rankedRows.first(where: \.isCurrentUser) {
                MetresPinnedRow(row: ownRow, periodLabel: viewModel.period.label.lowercased())
                    .padding(.bottom, Tokens.Size.navHeight + Tokens.Size.navBottomInset + 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.reload() }
        }
        .sheet(isPresented: $isShowingFilters) {
            RankingsFiltersSheet(filters: $viewModel.filters, ownGroup: viewModel.ownGroup, source: $viewModel.source)
        }
    }

    // MARK: - Controls

    private var periodSelection: Binding<Int> {
        Binding(
            get: { viewModel.period.rawValue },
            set: { viewModel.period = MetresLeaderboardViewModel.Period(rawValue: $0) ?? .week }
        )
    }

    /// "Senior men · My club · Erg + water".
    private var filterSummary: String {
        "\(viewModel.filters.captionText) · \(viewModel.source.label)"
    }

    private var rowerCount: String {
        let count = viewModel.rankedRows.count
        return "\(count) rower\(count == 1 ? "" : "s")"
    }

    // MARK: - Rank hero

    /// Lilac → card gradient card: "<period> volume · You · #N", your total, how far to the
    /// next place, and the group's leader.
    private var rankHeroCard: some View {
        let rows = viewModel.rankedRows
        let ownIndex = rows.firstIndex(where: \.isCurrentUser)
        let own = (ownIndex.map { rows[$0].metres } ?? 0).distanceParts(unit: distanceUnit)
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Text(heroTitle(rows: rows, ownIndex: ownIndex))
                .textStyle(Typography.overline)
                .foregroundStyle(Tokens.Accent.records)
            (Text(own.value) + Text(" \(own.unit)").font(.system(size: 16, weight: .bold)))
                .textStyle(Typography.heroNumber)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.top, Tokens.Spacing.loose)
            Text(heroSentence(rows: rows, ownIndex: ownIndex))
                .textStyle(Typography.bodyV3)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.vertical, Tokens.Spacing.tight)
            if let leader = rows.first {
                Text("Group leader · \(leader.isCurrentUser ? "You" : leader.name) · \(leader.metres.formattedDistance(unit: distanceUnit))")
                    .font(.system(size: 12))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(
                LinearGradient(
                    stops: [.init(color: Tokens.Accent.recordsSoft, location: 0), .init(color: Tokens.Surface.card, location: 0.75)],
                    startPoint: UnitPoint(x: 0.1, y: 0.2),
                    endPoint: UnitPoint(x: 0.9, y: 0.8)
                )
            )
        }
        .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    /// "Weekly volume · You · #2"; no place when you haven't logged any metres here.
    private func heroTitle(rows: [MetresLeaderboardViewModel.Row], ownIndex: Int?) -> String {
        let title = "\(periodAdjective) volume · You"
        guard let ownIndex else { return title }
        return "\(title) · #\(rows[ownIndex].rank)"
    }

    private var periodAdjective: String {
        switch viewModel.period {
        case .week: "Weekly"
        case .month: "Monthly"
        case .year: "Yearly"
        }
    }

    private func heroSentence(rows: [MetresLeaderboardViewModel.Row], ownIndex: Int?) -> String {
        guard let ownIndex else {
            return viewModel.viewerMatchesFilters
                ? "No metres logged this \(viewModel.period.label.lowercased()) yet"
                : "You are outside these filters"
        }
        let ownRow = rows[ownIndex]
        guard ownRow.rank > 1 else { return "You lead this group" }
        let aboveRow = rows[ownIndex - 1]
        let gap = max(aboveRow.metres - ownRow.metres, 0) + 1
        return "\(gap.formattedDistance(unit: distanceUnit)) to move into #\(aboveRow.rank)"
    }

    // MARK: - Leaderboard

    private var leaderboard: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
        return VStack(spacing: 0) {
            ForEach(viewModel.rankedRows) { row in
                leaderboardRow(row)
                if row.id != viewModel.rankedRows.last?.id {
                    Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                }
            }
        }
        .background(shape.fill(Tokens.Surface.card))
        .clipShape(shape)
        .overlay { shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    /// 72 pt row, columns 20 | 32 | name | score with 7 pt gaps. #1: ♛ and score in gold, gold
    /// tint and a 3 pt gold bar on the left. Your row: brand tint. Tap opens the profile.
    private func leaderboardRow(_ row: MetresLeaderboardViewModel.Row) -> some View {
        let isWinner = row.rank == 1
        let score = row.metres.distanceParts(unit: distanceUnit)
        return HStack(spacing: 7) {
            Text(isWinner ? "♛" : "\(row.rank)")
                .font(.system(size: 16, weight: .heavy))
                .tabularNumerals()
                .foregroundStyle(isWinner ? Tokens.Accent.rank : Tokens.Ink.secondary)
                .frame(width: 20)
            AvatarPlaceholder(diameter: 32, streakDays: row.streakDays, name: row.name, userId: row.userId)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.isCurrentUser ? "\(row.name) (you)" : row.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                Text(rowMeta(row))
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(score.value)
                    .font(.system(size: 14, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(isWinner ? Tokens.Accent.rank : Tokens.Ink.secondary)
                Text(score.unit == "m" ? "metres" : "km")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .frame(minHeight: 72)
        .background {
            if isWinner {
                Tokens.Accent.rankSoft
            } else if row.isCurrentUser {
                Tokens.Accent.brandSoft
            }
        }
        .overlay(alignment: .leading) {
            if isWinner {
                Rectangle().fill(Tokens.Accent.rank).frame(width: 3)
            }
        }
        .asButton { navigate(.profile(row.userId)) }
        .accessibilityLabel("Rank \(row.rank), \(row.name), \(row.metres.formattedDistance(unit: distanceUnit))")
        .modifier(TrackVisibility(isTracked: row.isCurrentUser, isVisible: $isOwnRowVisible))
    }

    private func rowMeta(_ row: MetresLeaderboardViewModel.Row) -> String {
        [row.club ?? "No club", row.level?.rawValue].compactMap { $0 }.joined(separator: " · ")
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                Text("Couldn't load the leaderboard")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text(errorMessage)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            } else if viewModel.viewerHasNoClub {
                Text("You're not in a club")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Join one to see how your metres stack up against your crew.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                Button("Find a club") { navigate(.findClub) }
                    .buttonStyle(.rpPrimary)
                    .padding(.top, 4)
            } else {
                Text("Nobody's logged metres here yet")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Post a session to be the first on the board.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
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

private struct TrackVisibility: ViewModifier {
    let isTracked: Bool
    @Binding var isVisible: Bool

    func body(content: Content) -> some View {
        if isTracked {
            content.onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .scrollView).maxY
            } action: { newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isVisible = newValue > 0
                }
            }
        } else {
            content
        }
    }
}

/// Your own row, floating above the nav when it has scrolled out of view.
struct MetresPinnedRow: View {
    let row: MetresLeaderboardViewModel.Row
    let periodLabel: String
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres

    var body: some View {
        HStack(spacing: 10) {
            Text("\(row.rank)")
                .font(.system(size: 16, weight: .heavy))
                .tabularNumerals()
                .foregroundStyle(row.rank == 1 ? Tokens.Accent.rank : Tokens.Ink.primary)
                .frame(width: 22)
            AvatarPlaceholder(diameter: 32, streakDays: row.streakDays, name: row.name, userId: row.userId)
            VStack(alignment: .leading, spacing: 1) {
                Text("You")
                    .textStyle(Typography.name)
                    .foregroundStyle(Tokens.Ink.primary)
                Text("\(row.club ?? "No club") · this \(periodLabel)")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(row.metres.formattedDistance(unit: distanceUnit))
                .font(.system(size: 16, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassSurface(in: Capsule())
        .padding(.horizontal, Tokens.Size.navSideInset)
    }
}

#Preview {
    MetresLeaderboardView(mode: .constant(.volume))
}
