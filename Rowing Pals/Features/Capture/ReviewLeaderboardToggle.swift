//
//  ReviewLeaderboardToggle.swift
//  Rowing Pals
//

import SwiftUI

/// "Include on leaderboards" on Review session: whether this session counts on the leaderboards.
/// Off still counts it in the rower's own profile and streak.
struct ReviewLeaderboardToggle: View {
    @Bindable var viewModel: ReviewSheetViewModel

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        Toggle(isOn: $viewModel.includeOnLeaderboards) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Include on leaderboards")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Your volume, and any piece or rep at a test distance or time.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .tint(Tokens.Accent.brand)
        .padding(.horizontal, Tokens.Spacing.loose)
        .padding(.vertical, Tokens.Spacing.tight)
        .frame(minHeight: 66)
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }
}
