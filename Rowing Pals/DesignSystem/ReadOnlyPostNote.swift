//
//  ReadOnlyPostNote.swift
//  Rowing Pals
//

import SwiftUI

/// In place of the comment box on a post a coach sees only because they coach its author:
/// coaches read, they don't comment or react (decision 40).
struct ReadOnlyPostNote: View {
    var body: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            Image(systemName: "eye")
                .foregroundStyle(Tokens.Ink.secondary)
                .accessibilityHidden(true)
            Text("You can see this as their coach. Only people they share it with can comment or react.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.vertical, Tokens.Spacing.loose)
        .background(Tokens.Base.ground)
    }
}
