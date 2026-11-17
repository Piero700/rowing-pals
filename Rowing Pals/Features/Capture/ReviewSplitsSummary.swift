//
//  ReviewSplitsSummary.swift
//  Rowing Pals
//

import SwiftUI

/// v3 split rows on Review session: a badge (the Main piece wears the workout label in brand),
/// "distance · time", and the split — one per piece, in order.
struct ReviewSplitsSummary: View {
    let viewModel: ReviewSheetViewModel
    /// Per-device display preference (DesignSystem/PaceDisplay.swift); the rows are a read-only recap.
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    var body: some View {
        GroupedSection {
            ForEach(Array(viewModel.segments.enumerated()), id: \.element.id) { index, segment in
                if index > 0 { GroupedDivider() }
                let isMain = segment.label == .main
                HStack(spacing: Tokens.Spacing.tight) {
                    Text(isMain ? (viewModel.sessionKind.testLabel ?? viewModel.zone.rawValue) : segment.label.rawValue.capitalized)
                        .textStyle(Typography.detail)
                        .tabularNumerals()
                        .foregroundStyle(isMain ? Tokens.Accent.brand : Tokens.Ink.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(segment.distanceM.formattedMetres) · \(segment.timeMs.formattedDurationMs)")
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                    Spacer(minLength: 0)
                    Text(segment.splitMs > 0 ? segment.splitMs.formattedPace(display: paceDisplay) : "—")
                        .textStyle(Typography.detail)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                }
                .padding(.horizontal, Tokens.Grouped.rowPadding)
                .frame(minHeight: Tokens.Grouped.rowHeight)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
