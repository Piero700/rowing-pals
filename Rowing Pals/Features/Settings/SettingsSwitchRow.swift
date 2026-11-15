//
//  SettingsSwitchRow.swift
//  Rowing Pals
//

import SwiftUI

/// A 66 pt Settings row with a switch; brand blue when on (v4).
struct SettingsSwitchRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(subtitle)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .tint(Tokens.Accent.brand)
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .frame(minHeight: Tokens.Size.row)
    }
}
