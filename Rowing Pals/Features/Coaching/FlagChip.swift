//
//  FlagChip.swift
//  Rowing Pals
//

import SwiftUI

/// A small rounded label on Coaching: red-tinted for a warning about the rower ("No session in
/// 12 days"), neutral for everything else ("Likely mis-tagged…", "Age 22", "Private account").
struct FlagChip: View {
    let text: String
    var isWarning = false

    var body: some View {
        Text(text)
            .textStyle(Typography.chip)
            .tabularNumerals()
            .foregroundStyle(isWarning ? Tokens.System.error : Tokens.Ink.secondary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .frame(minHeight: Tokens.Size.chip)
            .background(Capsule().fill(isWarning ? Tokens.System.error.opacity(Tokens.Coaching.flagChipTint) : Tokens.Surface.raised))
    }
}
