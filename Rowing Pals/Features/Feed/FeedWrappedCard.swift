//
//  FeedWrappedCard.swift
//  Rowing Pals
//

import SwiftUI

/// "Your Michaelmas 2026 Wrapped is ready" on the Feed for three weeks after a club term ends
/// (decision 92); tapping opens it.
struct FeedWrappedCard: View {
    let period: WrappedPeriod
    let onOpen: () -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Tokens.Spacing.loose) {
                RPIconView(icon: .star)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Tokens.Schedule.iconTile, height: Tokens.Schedule.iconTile)
                    .background(RoundedRectangle(cornerRadius: Tokens.Schedule.iconTileRadius, style: .continuous).fill(Tokens.Accent.brandSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Season Wrapped")
                        .textStyle(Typography.kicker)
                        .foregroundStyle(Tokens.Accent.brand)
                    Text("Your \(period.title) Wrapped is ready")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .multilineTextAlignment(.leading)
                    Text("Your metres, streaks, PBs and crew from the term. Share any page.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .contentShape(Self.cardShape)
        }
        .buttonStyle(IconPressStyle())
    }
}
