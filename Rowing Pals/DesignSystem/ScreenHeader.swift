//
//  ScreenHeader.swift
//  Rowing Pals
//

import SwiftUI

/// The header for a pushed screen (Settings, Rower profile, Find rowers, a test board, Log
/// workout…): a 44 pt glass back button, a 17 pt semibold title centred on the screen (v4), an
/// optional control on the right, at least 58 pt tall, on the screen ground.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    /// Optional control on the right: a delete button, a text action ("Help").
    @ViewBuilder var trailing: () -> Trailing

    /// v4: the title is centred on the screen, kept clear of the buttons on both sides so it
    /// stays centred, and cut short with "…" if it's too long.
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                GlassIconButton(systemImage: "chevron.left", accessibilityLabel: "Back", action: onBack)
                Spacer(minLength: 0)
                trailing()
            }
            Text(title)
                .textStyle(Typography.navTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Tokens.Size.iconButton + Tokens.Spacing.loose)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, Tokens.Spacing.tight)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, Tokens.Spacing.loose)
        .frame(minHeight: Tokens.Size.navHeight)
        .background(Tokens.Base.ground)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}
