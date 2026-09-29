//
//  AllPersonalBestsView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 11 — All personal bests, to v3 §11 (`docs/design/v3/RP Screen.dc.html`): opened
/// from "View all ›" on your profile. Header "Personal bests", one line of explanation, then a
/// tile for every standard test (the app keeps its nine; v3 draws seven). A tile with a result
/// opens that test's PB history.
struct AllPersonalBestsView: View {
    let tiles: [ProfileViewModel.PBTile]
    @Environment(\.dismiss) private var dismiss
    @State private var openTest: StandardTest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your recorded bests. Select a test to explore its history.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 14)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight), count: 2),
                    spacing: Tokens.Spacing.tight
                ) {
                    ForEach(tiles) { tile in
                        PBTileView(tile: tile) { openTest = tile.test }
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Personal bests") { dismiss() }
        }
        .background(Tokens.Base.ground)
        .edgeSwipeToDismiss()
        .fullScreenCover(item: $openTest) { test in
            PBHistoryView(test: test)
        }
    }
}
