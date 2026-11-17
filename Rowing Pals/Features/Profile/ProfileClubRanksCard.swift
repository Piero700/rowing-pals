//
//  ProfileClubRanksCard.swift
//  Rowing Pals
//

import SwiftUI

/// Another rower's place in their own club (decision 20): three columns — this week's volume, 2k,
/// 5k — each "#n" over its label.
struct ProfileClubRanksCard: View {
    let viewModel: ProfileViewModel

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        let ranks: [(Int?, String)] = [
            (viewModel.clubRanks?.weeklyVolume, "weekly volume"),
            (viewModel.clubRanks?.twoK, "2k test"),
            (viewModel.clubRanks?.fiveK, "5k test")
        ]
        HStack(spacing: 0) {
            ForEach(ranks.indices, id: \.self) { index in
                VStack(spacing: 2) {
                    Text(ProfileStatsCard.rankText(ranks[index].0))
                        .textStyle(Typography.rankValue)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(ranks[index].1)
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                if index < ranks.count - 1 {
                    Rectangle().fill(Tokens.Surface.line).frame(width: 1, height: 30)
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.loose)
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }
}
