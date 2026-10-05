//
//  TestsView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 6A — distance picker. Each tile shows the user's own PB for that
/// distance/time, or a quiet "—" if they haven't set one — the grid doubles
/// as a personal scoreboard. Tapping a tile opens its full leaderboard.
struct TestsView: View {
    @State private var viewModel = TestsViewModel()
    @State private var selectedTile: TestsViewModel.Tile?
    @State private var isAddingTest = false
    /// False when embedded under `RankingsView` (redesign, phase A) — this
    /// screen's own title is replaced by `RankingsHeader` there instead.
    var showsOwnTitle = true
    /// Only used when `showsOwnTitle` is false — see `RankingsView`.
    var mode: Binding<RankingsMode>?
    /// Goes up by one each time Rankings is tapped while already selected (decision 27).
    var reselects = 0

    var body: some View {
        // Direct ScrollView child, same constraint as FeedView — see its comment.
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if showsOwnTitle {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tests")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Tokens.Ink.primary)
                        Text("Your bests, and where they rank.")
                            .textStyle(Typography.bodySecondary)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .padding(.top, 8)
                } else if let mode {
                    RankingsHeader(mode: mode)
                }

                if viewModel.groupCaption != nil {
                    groupBestSection
                }

                if viewModel.groupCaption != nil {
                    Text("Your results")
                        .textStyle(Typography.overline)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 2)
                        .padding(.bottom, -8)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(viewModel.tiles) { tile in
                        distanceTile(tile)
                            .asButton { selectedTile = tile }
                    }
                    // Club admins and up add their club's own tests (decision 28).
                    if viewModel.clubTests.canManage {
                        addTestTile
                            .asButton { isAddingTest = true }
                            .accessibilityLabel("Add a club test")
                    }
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 16)
        }
        .scrollsToTopOnReselect(reselects) { ViewerContext.shared.invalidate(); await viewModel.loadOwnPBs() }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.loadOwnPBs() }
        .refreshable { ViewerContext.shared.invalidate(); await viewModel.loadOwnPBs() }
        .fullScreenCover(item: $selectedTile) { tile in
            TestLeaderboardView(test: tile.test, onDelete: deleteAction(for: tile))
        }
        .sheet(isPresented: $isAddingTest) {
            AddClubTestView(existing: viewModel.clubTests.tests) { await viewModel.loadOwnPBs() }
        }
        // Joining or leaving a club changes which club tests show.
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.loadOwnPBs() }
        }
    }

    /// Only a club test, and only for its admins and up.
    private func deleteAction(for tile: TestsViewModel.Tile) -> (() async throws -> Void)? {
        guard let clubTest = tile.clubTest, viewModel.clubTests.canManage else { return nil }
        return { try await viewModel.delete(clubTest) }
    }

    // MARK: - Best in your group

    /// v4 `RankingsTests`: a header with the group, then a gold card per test — the group's
    /// best, who holds it, and how you stand. Tapping opens that test's board.
    private var groupBestSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            HStack(alignment: .firstTextBaseline) {
                Text("Best in your group")
                    .textStyle(Typography.overline)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer()
                if let caption = viewModel.groupCaption {
                    Text(caption)
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            .padding(.horizontal, 2)
            HStack(spacing: Tokens.Spacing.gap) {
                if viewModel.groupBests.isEmpty {
                    // Same size as the real cards while their numbers load.
                    ForEach(TestsViewModel.groupBestKeys, id: \.self) { _ in
                        groupBestPlaceholder
                    }
                } else {
                    ForEach(viewModel.groupBests) { best in
                        groupBestCard(best)
                            .asButton {
                                selectedTile = viewModel.tiles.first { $0.test.key == best.test.key }
                            }
                            .accessibilityLabel(groupBestAccessibility(best))
                    }
                }
            }
        }
        .padding(.top, Tokens.Spacing.tight)
    }

    private func groupBestCard(_ best: GroupBest) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return VStack(alignment: .leading, spacing: Tokens.Spacing.gap) {
            HStack {
                Text("\(best.test.label) · Best")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Accent.rank)
                Spacer()
                Image(systemName: "chevron.right")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Accent.rank)
            }
            HStack(spacing: Tokens.Spacing.tight) {
                if let leader = best.leader {
                    AvatarPlaceholder(diameter: Tokens.Size.commentAvatar, name: leader.name, userId: leader.userId)
                    Text(best.leaderIsViewer ? "You" : leader.name)
                        .textStyle(Typography.name)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                } else {
                    Text("No one yet")
                        .textStyle(Typography.name)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(best.leader?.timeMs.formattedDurationMs ?? "—")
                    .textStyle(Typography.groupBestValue)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(best.standing)
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.groupBestCard, alignment: .topLeading)
        .background { shape.fill(Tokens.Accent.rankSoft) }
        .overlay { shape.strokeBorder(Tokens.Accent.rank.opacity(0.35), lineWidth: 1) }
    }

    private var groupBestPlaceholder: some View {
        RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
            .fill(Tokens.Accent.rankSoft)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.groupBestCard)
            .accessibilityHidden(true)
    }

    private func groupBestAccessibility(_ best: GroupBest) -> String {
        guard let leader = best.leader else { return "\(best.test.label): \(best.standing)" }
        return "\(best.test.label) best in your group: \(best.leaderIsViewer ? "you" : leader.name), \(leader.timeMs.formattedDurationMs). \(best.standing). Open the board"
    }

    /// The trailing "+ Add test" tile, the same size as a test tile.
    private var addTestTile: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .bold))
            Text("Add test")
                .textStyle(Typography.pill)
        }
        .foregroundStyle(Tokens.Accent.brand)
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.testTile)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.08))
        }
    }

    private func distanceTile(_ tile: TestsViewModel.Tile) -> some View {
        VStack(spacing: 6) {
            Text(tile.test.label)
                .font(.system(size: 21, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(tile.displayValue ?? "—")
                .font(.system(size: 13.5, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let predicted = tile.predicted {
                Text("Predicted \(predicted)")
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Accent.records)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.testTile)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.08))
        }
    }
}

#Preview {
    TestsView()
}
