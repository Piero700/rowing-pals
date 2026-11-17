//
//  ProfilePrivateCard.swift
//  Rowing Pals
//

import SwiftUI

/// Shown in place of every stat for a private account the viewer is not approved to see.
struct ProfilePrivateCard: View {
    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(spacing: Tokens.Spacing.gap) {
            RPIconView(icon: .lock, size: Tokens.Icon.feature)
                .foregroundStyle(Tokens.Ink.secondary)
            Text("This profile is private")
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Tokens.Ink.primary)
            Text("Send a follow request to see their stats, personal bests, followers and following.")
                .textStyle(Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }
}
