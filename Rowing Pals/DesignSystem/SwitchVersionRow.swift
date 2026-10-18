//
//  SwitchVersionRow.swift
//  Rowing Pals
//

import SwiftUI

/// **Switch to coaching** / **Switch to rowing** for someone who rows and coaches (decision 67): one
/// card row, the same in the rower's Settings and on the coach's Profile (user, 2026-10-18) — the
/// switch icon in a soft brand circle, the action in brand blue, a line under it and a chevron.
struct SwitchVersionRow: View {
    /// True for Switch to coaching (from the rower version), false for Switch to rowing.
    let toCoaching: Bool
    let action: () -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.loose) {
                RPIconView(icon: .switchMode)
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Tokens.Size.rowIcon, height: Tokens.Size.rowIcon)
                    .background(Circle().fill(Tokens.Accent.brandSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(toCoaching ? "Switch to coaching" : "Switch to rowing")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Accent.brand)
                    Text("You row and coach. The app opens in the one you used last.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .frame(minHeight: Tokens.Size.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .clipShape(Self.cardShape)
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }
}
