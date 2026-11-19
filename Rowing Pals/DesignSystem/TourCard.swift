//
//  TourCard.swift
//  Rowing Pals
//

import SwiftUI

/// One card of the tour: "2 of 5", a title, a line or two on what this part of the app is for,
/// then Skip and Next (Done on the last card).
struct TourCard: View {
    let step: TourStep
    let progress: String
    let isLast: Bool
    let onSkip: () -> Void
    let onNext: () -> Void

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            Text(progress)
                .textStyle(Typography.kicker)
                .monospacedDigit()
                .foregroundStyle(Tokens.Ink.secondary)
            Text(step.title)
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Text(step.body)
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tokens.Spacing.gap) {
                if !isLast {
                    Button("Skip", action: onSkip)
                        .buttonStyle(.rpText)
                }
                Spacer(minLength: 0)
                Button(isLast ? "Done" : "Next", action: onNext)
                    .buttonStyle(.rpPrimary)
                    .fixedSize()
            }
            .padding(.top, Tokens.Spacing.tight)
        }
        .padding(Tokens.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(in: Self.shape)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
