//
//  MetresLeaderboardView.swift
//  Rowing Pals
//

import SwiftUI

/// Rankings → Volume, to v3 (`docs/design/v3/RP Screen.dc.html` §03): mode control, the lilac
/// rank-hero card, Gender and Level selects, the scope control, a "This week · N rowers match"
/// caption, and one leaderboard card of 72 pt rows (#1 in gold with ♛ and a gold edge bar, your
/// row tinted brand). Also keeps Week / Month / Year and All / Erg / Water (decision 18) and
/// scope My club / Following only (decision 17). Distances follow the km toggle (decision 3).
struct MetresLeaderboardView: View {
    @Binding var mode: RankingsMode

    @State private var viewModel = MetresLeaderboardViewModel()
    @State private var isOwnRowVisible = true
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres
    @Environment(\.navigate) private var navigate

    /// v3 order without the cancelled app-wide "All": My club, then Following.
    private static let scopes: [SocialScope] = [.myClub, .following]

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
                    select(title: "Gender", value: genderLabel, options: [("All genders", nil), ("Male", .male), ("Female", .female)]) {
                        viewModel.filters.gender = $0
                    }
                    select(title: "Level", value: levelLabel, options: [("All levels", nil), ("Novice", .novice), ("Senior", .senior)]) {
                        viewModel.filters.level = $0
                    }
                }
                .padding(.top, 15)
                .padding(.bottom, Tokens.Spacing.gap)

                // v3 wording: "My club", "Following".
                PillSegmentedControl(options: ["My club", "Following"], selection: scopeSelection)

                sourcePills
                    .padding(.top, Tokens.Spacing.loose)

                Text(matchCaption)
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 2)
                    .padding(.vertical, Tokens.Spacing.loose)

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
    }

    // MARK: - Controls

    private var periodSelection: Binding<Int> {
        Binding(
            get: { viewModel.period.rawValue },
            set: { viewModel.period = MetresLeaderboardViewModel.Period(rawValue: $0) ?? .week }
        )
    }

    private var scopeSelection: Binding<Int> {
        Binding(
            get: { Self.scopes.firstIndex(of: viewModel.filters.scope) ?? 0 },
            set: { viewModel.filters.scope = Self.scopes[$0] }
        )
    }

    private var genderLabel: String {
        switch viewModel.filters.gender {
        case .male: "Male"
        case .female: "Female"
        case nil: "All genders"
        }
    }

    private var levelLabel: String {
        switch viewModel.filters.level {
        case .novice: "Novice"
        case .senior: "Senior"
        case nil: "All levels"
        }
    }

    /// v3 select: 12 pt muted label over a 44 pt raised field (radius 15, 1 pt line).
    private func select<Value>(
        title: String, value: String, options: [(String, Value?)], onPick: @escaping (Value?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Tokens.Ink.secondary)
            Menu {
                ForEach(options.indices, id: \.self) { index in
                    Button(options[index].0) { onPick(options[index].1) }
                }
            } label: {
                HStack {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .padding(Tokens.Spacing.loose)
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.minTap)
                .background {
                    RoundedRectangle(cornerRadius: Tokens.Radius.select, style: .continuous).fill(Tokens.Surface.raised)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.select, style: .continuous)
                        .strokeBorder(Tokens.Surface.line, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.select, style: .continuous))
            }
            .accessibilityLabel("\(title): \(value)")
        }
        .frame(maxWidth: .infinity)
    }

    /// All / Erg / Water (decision 18) as glass pills.
    private var sourcePills: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            ForEach(MetresLeaderboardViewModel.Source.allCases, id: \.self) { source in
                Button(source.label) { viewModel.source = source }
                    .buttonStyle(.rpPill(isOn: viewModel.source == source, minHeight: 40))
                    .accessibilityAddTraits(viewModel.source == source ? .isSelected : [])
            }
        }
    }

    private var matchCaption: String {
        let count = viewModel.rankedRows.count
        return "This \(viewModel.period.label.lowercased()) · \(count) rower\(count == 1 ? "" : "s") match"
    }

    // MARK: - Rank hero

    /// Lilac → card gradient card: "<period> volume · You", your total, how far to the next
    /// place, and the overall leader.
    private var rankHeroCard: some View {
        let rows = viewModel.rankedRows
        let ownIndex = rows.firstIndex(where: \.isCurrentUser)
        let own = (ownIndex.map { rows[$0].metres } ?? 0).distanceParts(unit: distanceUnit)
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(periodAdjective) volume · You")
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
                Text("Overall leader · \(leader.isCurrentUser ? "You" : leader.name) · \(leader.metres.formattedDistance(unit: distanceUnit))")
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
            AvatarPlaceholder(diameter: 32, streakDays: row.streakDays, name: row.name)
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
            AvatarPlaceholder(diameter: 32, streakDays: row.streakDays, name: row.name)
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
