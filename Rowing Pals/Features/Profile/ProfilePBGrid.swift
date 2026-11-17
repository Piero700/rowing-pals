//
//  ProfilePBGrid.swift
//  Rowing Pals
//

import SwiftUI

/// Profile's PBs tab: every standard test's tile, two to a row.
struct ProfilePBGrid: View {
    let tiles: [ProfileViewModel.PBTile]
    let onOpenTest: (StandardTest) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight), count: 2),
                  spacing: Tokens.Spacing.tight) {
            ForEach(tiles) { tile in
                PBTileView(tile: tile) { onOpenTest(tile.test) }
            }
        }
        .padding(.top, Tokens.Spacing.sectionTop)
    }
}
