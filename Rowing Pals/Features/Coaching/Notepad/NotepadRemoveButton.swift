//
//  NotepadRemoveButton.swift
//  Rowing Pals
//

import SwiftUI

/// The ✕ that takes a text box or table off the notepad: a full 44 pt tap target.
struct NotepadRemoveButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RPIconView(icon: .close, size: Tokens.Icon.small)
                .foregroundStyle(Tokens.Ink.faint)
                .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(label)
    }
}
