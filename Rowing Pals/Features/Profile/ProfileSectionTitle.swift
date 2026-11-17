//
//  ProfileSectionTitle.swift
//  Rowing Pals
//

import SwiftUI

/// v3 section title on Profile: 12 pt heavy uppercase, muted, 20 top / 9 bottom.
struct ProfileSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 2)
            .padding(.top, Tokens.Spacing.sectionTop)
            .padding(.bottom, Tokens.Spacing.sectionBottom)
            .accessibilityAddTraits(.isHeader)
    }
}
