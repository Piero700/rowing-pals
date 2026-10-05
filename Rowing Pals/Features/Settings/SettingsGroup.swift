//
//  SettingsGroup.swift
//  Rowing Pals
//

import SwiftUI

/// A v4 settings section: its title in small capitals, one card (radius 30, card fill, card
/// edge) of rows, and an optional note beneath (SettingsProfile, SettingsPrivacy).
struct SettingsGroup<Content: View>: View {
    let title: String?
    var footnote: String?
    @ViewBuilder var content: () -> Content

    private static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .textStyle(Typography.sectionTitle)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, Tokens.Spacing.group)
                    .padding(.bottom, Tokens.Spacing.tight)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content() }
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .clipShape(Self.cardShape)
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            if let footnote {
                Text(footnote)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, Tokens.Spacing.tight)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
