//
//  ReviewTotalCard.swift
//  Rowing Pals
//

import SwiftUI

/// v3 "Workout total" card on Review session: overline, 29 pt heavy number with a small muted unit.
struct ReviewTotalCard: View {
    let totalDistanceM: Int

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Workout total")
                .textStyle(Typography.overline)
                .foregroundStyle(Tokens.Ink.secondary)
            (Text(totalDistanceM > 0 ? totalDistanceM.formattedWithGrouping : "—")
                + Text(totalDistanceM > 0 ? " m" : "").font(Typography.detail.font).foregroundColor(Tokens.Ink.secondary))
                .textStyle(Typography.reviewResult)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(Tokens.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        .accessibilityElement(children: .combine)
    }
}
