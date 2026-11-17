//
//  ProfileChip.swift
//  Rowing Pals
//

import SwiftUI

/// The small grey capsule beside a Profile section title ("12 weeks", "5 active days").
struct ProfileChip: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(Typography.fieldLabel)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, Tokens.Spacing.tight)
            .frame(minHeight: 27)
            .background(Capsule().fill(Tokens.Surface.raised))
    }
}
