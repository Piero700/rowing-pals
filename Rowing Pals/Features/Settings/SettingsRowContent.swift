//
//  SettingsRowContent.swift
//  Rowing Pals
//

import SwiftUI

/// A Settings row (v4): title 15 semibold, an optional 13 description, a trailing control; 66 pt
/// tall with a description, 56 without. A struct, not a function returning `some View`: Settings
/// crashed on the iPhone when its view type, built from nested opaque helpers, grew too deep for the
/// main thread's stack (15 Nov 2026).
struct SettingsRowContent<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var titleColor: Color = Tokens.Ink.primary
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .tabularNumerals()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .frame(minHeight: subtitle == nil ? Tokens.Size.rowCompact : Tokens.Size.row)
        .contentShape(Rectangle())
    }
}
