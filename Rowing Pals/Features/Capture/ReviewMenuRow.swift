//
//  ReviewMenuRow.swift
//  Rowing Pals
//

import SwiftUI

/// The closed look of a dropdown on Review session: value on the left, chevrons on the right.
struct ReviewMenuRow: View {
    let text: String

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.select, style: .continuous)

    var body: some View {
        HStack {
            Text(text)
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Ink.primary)
            Spacer()
            RPIconView(icon: .chevronUpDown, size: Tokens.Icon.small)
                .textStyle(Typography.fieldLabel)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(Tokens.Spacing.loose)
        .frame(minHeight: Tokens.Size.minTap)
        .background { Self.shape.fill(Tokens.Surface.raised) }
        .overlay { Self.shape.strokeBorder(Tokens.Surface.line, lineWidth: Tokens.Grouped.hairline) }
        .contentShape(Self.shape)
    }
}
