//
//  InsetCornerGlyph.swift
//  Rowing Pals
//

import SwiftUI

/// A tiny outline-plus-filled-corner glyph standing in for "inset position"
/// — no SF Symbol names this exact concept precisely enough, so this draws
/// it directly rather than guessing at one. Used both as the capture
/// screen's trigger-button icon (reflecting the current corner) and as each
/// option's icon inside `InsetCornerPickerView`.
struct InsetCornerGlyph: View {
    let corner: InsetCorner
    var tint: Color = Tokens.Ink.primary

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(tint.opacity(0.5), lineWidth: 1.5)
            .overlay(alignment: corner.alignment) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: 9, height: 7)
                    .padding(3)
            }
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(InsetCorner.allCases) { corner in
            InsetCornerGlyph(corner: corner)
                .frame(width: 32, height: 32)
        }
    }
    .padding()
    .background(Tokens.Base.ground)
}
