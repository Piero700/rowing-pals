//
//  SettingsStackedRow.swift
//  Rowing Pals
//

import SwiftUI

/// The v4 units row: title and description on top, the full-width control beneath.
struct SettingsStackedRow<Control: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(subtitle)
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            control()
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.top, Tokens.Spacing.gap)
        .padding(.bottom, Tokens.Spacing.loose)
    }
}
