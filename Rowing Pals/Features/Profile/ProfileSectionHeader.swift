//
//  ProfileSectionHeader.swift
//  Rowing Pals
//

import SwiftUI

/// A Profile section title with something on the right (a chip, "View all"), both centred on one
/// line, with the section spacing around the whole row.
struct ProfileSectionHeader<Trailing: View>: View {
    let text: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(text)
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 2)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
        .padding(.top, Tokens.Spacing.sectionTop - 8)
        .padding(.bottom, Tokens.Spacing.sectionBottom - 4)
    }
}
