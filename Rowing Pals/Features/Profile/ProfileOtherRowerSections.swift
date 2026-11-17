//
//  ProfileOtherRowerSections.swift
//  Rowing Pals
//

import SwiftUI

/// Another rower's profile, v3 §08 exactly (decision 22): this week's volume, two personal bests and
/// their place in their own club — no tabs, chart, grid or posts. A private account you aren't
/// approved for shows only the lock card.
struct ProfileOtherRowerSections: View {
    let viewModel: ProfileViewModel
    let onOpenTest: (StandardTest) -> Void

    /// v3 §08's two PB tiles.
    private static let pbKeys = ["2k", "30min"]

    var body: some View {
        if viewModel.isLocked {
            ProfilePrivateCard()
                .padding(.top, Tokens.Spacing.loose)
        } else {
            ProfileSectionTitle(text: "Volume · This week")
            ProfileStatsCard(stats: [
                .init(value: ProfileStatsCard.compactMetres(currentWeekVolumeM), label: "metres"),
                .init(value: ProfileStatsCard.rankText(viewModel.clubRanks?.weeklyVolume), label: "volume ranking"),
                .init(value: "\(viewModel.weekSessionCount)", label: "sessions"),
                .init(value: "\(viewModel.streakDays)", label: "streak days")
            ])

            ProfileSectionTitle(text: "Personal bests")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight), count: 2),
                      spacing: Tokens.Spacing.tight) {
                ForEach(viewModel.pbTiles.filter { Self.pbKeys.contains($0.test.key) }) { tile in
                    // Decision 21: their all-time best, not a season best.
                    PBTileView(tile: tile, label: tile.test.longTitle, footnote: "Personal best") { onOpenTest(tile.test) }
                }
            }

            // Decision 20: ranks within their own club — app-wide rankings were dropped (17).
            if viewModel.clubName != nil {
                ProfileSectionTitle(text: "Club rankings")
                ProfileClubRanksCard(viewModel: viewModel)
            }
        }
    }

    private var currentWeekVolumeM: Int {
        viewModel.weeklyVolumes.first(where: \.isCurrentWeek)?.distanceM ?? 0
    }
}
