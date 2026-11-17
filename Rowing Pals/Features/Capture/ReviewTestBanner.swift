//
//  ReviewTestBanner.swift
//  Rowing Pals
//

import SwiftUI

/// "This looks like a 2k test." on Review session. Yes only picks the test in the Session type
/// dropdown; the `test_results` row is written when the post is saved.
struct ReviewTestBanner: View {
    let test: StandardTest
    let viewModel: ReviewSheetViewModel

    private static let buttonShape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 2) {
                Text("This looks like a \(test.label) test.")
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Call it a \(test.label) test? It goes on the \(test.label) leaderboard either way.")
                    .textStyle(Typography.bodySecondary)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Button {
                viewModel.decideTest(accepted: true)
            } label: {
                Text("Yes")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Base.dark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, Tokens.Spacing.tight)
                    .background { Self.buttonShape.fill(Tokens.Accent.brand) }
            }
            Button {
                viewModel.decideTest(accepted: false)
            } label: {
                Text("No")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, Tokens.Spacing.tight)
                    .background { Self.buttonShape.fill(Tokens.Ink.primary.opacity(0.1)) }
            }
        }
        .padding(Tokens.Spacing.loose)
        .background { Self.shape.fill(Tokens.Accent.brand.opacity(0.14)) }
        .overlay { Self.shape.strokeBorder(Tokens.Accent.brand.opacity(0.35), lineWidth: 1) }
        .buttonStyle(.plain)
    }
}
