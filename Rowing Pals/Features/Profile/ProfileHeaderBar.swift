//
//  ProfileHeaderBar.swift
//  Rowing Pals
//

import SwiftUI

/// Your own Profile's pinned header: the "Profile" title and the glass Settings button.
struct ProfileHeaderBar: View {
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Spacing.gap) {
            Text("Profile")
                .textStyle(Typography.largeTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            GlassIconButton(icon: .settings, accessibilityLabel: "Settings", action: onSettings)
        }
        .padding(.top, Tokens.Spacing.tight)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, 14)
        .frame(minHeight: Tokens.Size.headerMinHeight)
        .background(Tokens.Base.ground)
    }
}
