//
//  SectionTitle.swift
//  Rowing Pals
//

import SwiftUI

/// v3's section heading: 12 pt heavy uppercase, muted, 20 above and 9 below.
struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .tabularNumerals()
            .padding(.horizontal, 2)
            .padding(.top, Tokens.Spacing.sectionTop)
            .padding(.bottom, Tokens.Spacing.sectionBottom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
