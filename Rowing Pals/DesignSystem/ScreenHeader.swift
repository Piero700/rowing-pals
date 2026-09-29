//
//  ScreenHeader.swift
//  Rowing Pals
//

import SwiftUI

/// v3's header for a pushed screen (Settings, Rower profile, Find rowers…): a 44 pt glass back
/// button and a 17 pt bold title, left-aligned, at least 58 pt tall, on the screen ground.
struct ScreenHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Spacing.gap) {
            GlassIconButton(systemImage: "chevron.left", accessibilityLabel: "Back", action: onBack)
            Text(title)
                .textStyle(Typography.navTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, 14)
        .frame(minHeight: Tokens.Size.navHeight)
        .background(Tokens.Base.ground)
    }
}
