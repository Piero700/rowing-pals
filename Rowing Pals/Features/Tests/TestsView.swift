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
    @State private var selectedTest: StandardTest?

    var body: some View {
        // Direct ScrollView child, same constraint as FeedView — see its comment.
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tests")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                    Text("Your bests, and where they rank.")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .padding(.top, 8)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(viewModel.tiles) { tile in
                        distanceTile(tile)
                            .onTapGesture { selectedTest = tile.test }
                    }
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 16)
        }
        .background(Tokens.Base.ground)
        .task { await viewModel.loadOwnPBs() }
        .refreshable { await viewModel.loadOwnPBs() }
        .fullScreenCover(item: $selectedTest) { test in
            TestLeaderboardView(test: test)
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
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 106)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.08))
        }
    }
}

#Preview {
    TestsView()
}
