//
//  ReviewSectionTitle.swift
//  Rowing Pals
//

import SwiftUI

/// A section title on Review session ("Splits", "Caption", "Photos").
struct ReviewSectionTitle: View {
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
