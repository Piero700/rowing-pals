//
//  MetresLeaderboardView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 5 — Metres leaderboard, aggregated from `daily_totals` only
/// (never `sessions`, per task 13). UK spelling "Metres" per CLAUDE.md's
/// domain vocabulary.
struct MetresLeaderboardView: View {
    @State private var viewModel = MetresLeaderboardViewModel()
    /// Whether the current user's own row is visible in the scrollable
    /// list — the pinned row below only shows once it scrolls out of view,
    /// so they never appear twice on screen at once.
    @State private var isOwnRowVisible = true
    /// False when embedded under `RankingsView` (redesign, phase A) — this
    /// screen's own title is replaced by `RankingsHeader` there instead.
    var showsOwnTitle = true
    /// Only used when `showsOwnTitle` is false — see `RankingsView`.
    var mode: Binding<RankingsMode>?
    /// Redesign phase B — per-device display preference, not synced to
    /// the profile. See DesignSystem/DistanceUnit.swift.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres
    /// Redesign phase D — single Filters sheet replacing inline chips, see
    /// RankingsFilters.swift.
    @State private var isShowingFilters = false

    var body: some View {
        // Direct ScrollView child, same constraint as FeedView — see its comment.
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if showsOwnTitle {
                    Text("Metres")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(.top, 8)
                } else if let mode {
                    RankingsHeader(mode: mode)
                }

                PillSegmentedControl(options: MetresLeaderboardViewModel.Period.allCases.map(\.label), selection: periodSelection)

                HStack(spacing: 7) {
                    ForEach(MetresLeaderboardViewModel.Source.allCases, id: \.self) { source in
                        FilterChip(label: source.label, isSelected: viewModel.source == source)
                            .onTapGesture { viewModel.source = source }
                    }
                }

                // Redesign phase D — Gender/Level/Scope collapse into one
                // "Filters" sheet with a caption stating the composed
                // filter, replacing what used to be inline chips/text here.
                // Source above stays inline: it picks *which figure* ranks
                // rows, not *who* is included, so it isn't one of the three
                // AND'd axes the sheet covers.
                HStack(spacing: 10) {
                    RankingsFiltersButton(filters: viewModel.filters) { isShowingFilters = true }
                }
                .padding(.top, 2)

                if viewModel.rankedRows.isEmpty {
                    emptyState
                } else {
                    rankHeroCard
                        .padding(.top, 4)

                    VStack(spacing: 8) {
                        ForEach(viewModel.rankedRows) { row in
                            if row.rank <= 3 {
                                podiumRow(row)
                            } else {
                                restRow(row)
                            }
                        }
                    }
                    .padding(.top, 6)

                    HStack(spacing: 14) {
                        legendSwatch(opacity: 0.75, label: "Erg")
                        legendSwatch(opacity: 0.28, label: "Water")
                    }
                    .padding(.top, 2)
                }

                Color.clear.frame(height: 60)
            }
            .padding(.horizontal, 14)
        }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .bottom) {
            if !isOwnRowVisible, let ownRow = viewModel.rankedRows.first(where: \.isCurrentUser) {
                MetresPinnedRow(row: ownRow, periodLabel: viewModel.period.label.lowercased())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.reload() }
        // `simultaneousGesture`, not `gesture` — this must never win
        // exclusively over the ScrollView's own vertical pan recognizer,
        // only additionally recognize a clearly horizontal drag anywhere
        // on the page, Safari-back/forward-swipe style.
        .simultaneousGesture(periodSwipeGesture)
        .sheet(isPresented: $isShowingFilters) {
            RankingsFiltersSheet(filters: $viewModel.filters)
        }
    }

    private var periodSelection: Binding<Int> {
        Binding(
            get: { viewModel.period.rawValue },
            set: { viewModel.period = MetresLeaderboardViewModel.Period(rawValue: $0) ?? .week }
        )
    }

    /// Swiping anywhere on the page — not just the Week/Month/Year control —
    /// steps to the next/previous period, Safari-style: left advances
    /// (Week → Month → Year), right goes back, clamped at either end
    /// rather than wrapping.
    private var periodSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                advancePeriod(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func advancePeriod(by delta: Int) {
        let periods = MetresLeaderboardViewModel.Period.allCases
        guard
            let currentIndex = periods.firstIndex(of: viewModel.period),
            periods.indices.contains(currentIndex + delta)
        else { return }
        viewModel.period = periods[currentIndex + delta]
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                Text("Couldn't load the leaderboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text(errorMessage)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Nobody's logged metres here yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Post a session to be the first on the board.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    /// Redesign phase D — the rank-hero card atop the Volume ranked list,
    /// per docs/design/rowing-pals-redesign-handoff-v2.md §2 Screen 03:
    /// the viewer's own total for the selected period, a live sentence, and
    /// the overall leader's name. Rendered in the lilac `.records` role,
    /// same as every other PB/rank-hero surface in the app — never gold,
    /// which is reserved for rank-movement only.
    @ViewBuilder
    private var rankHeroCard: some View {
        let rows = viewModel.rankedRows
        let ownIndex = rows.firstIndex(where: \.isCurrentUser)
        let leader = rows.first

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("You")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer()
                if let leader, !leader.isCurrentUser {
                    Text("\(leader.name) leads")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
            }
            Text((ownIndex.map { rows[$0].metres } ?? 0).formattedDistance(unit: distanceUnit))
                .font(.system(size: 32, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
            Text(heroSentence(rows: rows, ownIndex: ownIndex))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Accent.records)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Tokens.Accent.records.opacity(0.1))
        }
    }

    private func heroSentence(rows: [MetresLeaderboardViewModel.Row], ownIndex: Int?) -> String {
        guard let ownIndex else { return "You are outside these filters" }
        let ownRow = rows[ownIndex]
        guard ownRow.rank > 1 else { return "You lead this group" }
        let aboveRow = rows[ownIndex - 1]
        let gap = max(aboveRow.metres - ownRow.metres, 0) + 1
        return "\(gap.formattedDistance(unit: distanceUnit)) to move into #\(aboveRow.rank)"
    }

    private func podiumRow(_ row: MetresLeaderboardViewModel.Row) -> some View {
        HStack(spacing: 12) {
            Text("\(row.rank)")
                .font(.system(size: 26, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Accent.records)
                .frame(width: 26)
            AvatarPlaceholder(diameter: 42, streakDays: row.streakDays)
            rowLabels(row)
            Text(row.metres.formattedDistance(unit: distanceUnit))
                .font(.system(size: 19, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Accent.records.opacity(0.07))
        }
        .modifier(TrackVisibility(isTracked: row.isCurrentUser, isVisible: $isOwnRowVisible))
    }

    private func restRow(_ row: MetresLeaderboardViewModel.Row) -> some View {
        HStack(spacing: 12) {
            Text("\(row.rank)")
                .font(.system(size: 17, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(width: 26)
            AvatarPlaceholder(diameter: 38, streakDays: row.streakDays)
            rowLabels(row)
            Text(row.metres.formattedDistance(unit: distanceUnit))
                .font(.system(size: 17, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.05))
        }
        .modifier(TrackVisibility(isTracked: row.isCurrentUser, isVisible: $isOwnRowVisible))
    }

    private func rowLabels(_ row: MetresLeaderboardViewModel.Row) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(row.name)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
            Text(row.club ?? "No club")
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Ink.secondary)
                .lineLimit(1)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle().fill(Tokens.Ink.primary.opacity(0.75))
                        .frame(width: geometry.size.width * row.ergFraction)
                    Rectangle().fill(Tokens.Ink.primary.opacity(0.28))
                }
            }
            .frame(height: 3)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendSwatch(opacity: Double, label: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(Tokens.Ink.primary.opacity(opacity)).frame(width: 14, height: 3)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }
}

/// Reports whether the current user's row has scrolled out of the visible
/// area, so the pinned row can appear only once its inline counterpart is
/// gone — never both at once.
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

/// The pinned "You" row shown above the floating tab bar once the user's
/// own row scrolls out of view — an overlay on this screen's ScrollView,
/// not a TabView-level accessory (see the design handoff doc for why).
struct MetresPinnedRow: View {
    let row: MetresLeaderboardViewModel.Row
    let periodLabel: String
    /// Redesign phase B — per-device display preference, not synced to
    /// the profile. See DesignSystem/DistanceUnit.swift.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres

    var body: some View {
        HStack(spacing: 12) {
            Text("\(row.rank)")
                .font(.system(size: 20, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(row.rank <= 3 ? Tokens.Accent.records : Tokens.Ink.primary)
                .frame(width: 26)
            AvatarPlaceholder(diameter: 38, streakDays: row.streakDays)
            VStack(alignment: .leading, spacing: 1) {
                Text("You")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("\(row.club ?? "No club") · this \(periodLabel)")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(row.metres.formattedDistance(unit: distanceUnit))
                .font(.system(size: 18, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassSurface(cornerRadius: 24)
        .padding(.horizontal, 16)
    }
}

#Preview {
    MetresLeaderboardView()
}
