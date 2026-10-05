//
//  VolumeBars.swift
//  Rowing Pals
//

import SwiftUI

/// Eight weeks of metres as bars (CoachRower): past weeks faint, this week in brand, each bar
/// rounder on top than at its foot; the first week's date under the left, "This week" under
/// the right.
struct VolumeBars: View {
    /// Metres per week, oldest first.
    let weeks: [Int]
    let weekStarts: [Date]

    var body: some View {
        let tallest = max(weeks.max() ?? 0, 1)
        VStack(spacing: Tokens.Spacing.tight) {
            HStack(alignment: .bottom, spacing: Tokens.Spacing.tight) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, metres in
                    let isThisWeek = index == weeks.count - 1
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            UnevenRoundedRectangle(
                                topLeadingRadius: Tokens.Coaching.barTopRadius,
                                bottomLeadingRadius: Tokens.Coaching.barFootRadius,
                                bottomTrailingRadius: Tokens.Coaching.barFootRadius,
                                topTrailingRadius: Tokens.Coaching.barTopRadius,
                                style: .continuous
                            )
                            .fill(isThisWeek ? Tokens.Accent.brand : Tokens.Ink.primary.opacity(Tokens.Coaching.pastBarOpacity))
                            .frame(height: max(metres > 0 ? 4 : 0, geometry.size.height * CGFloat(metres) / CGFloat(tallest)))
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel(label(index: index, metres: metres))
                }
            }
            .frame(height: Tokens.Size.volumeChart)

            HStack {
                Text(weekStarts.first.map { $0.formatted(.dateTime.day().month(.abbreviated)) } ?? "")
                Spacer()
                Text("This week")
            }
            .textStyle(Typography.statLabel)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
        }
    }

    private func label(index: Int, metres: Int) -> String {
        let week = index < weekStarts.count ? weekStarts[index].formatted(.dateTime.day().month(.wide)) : ""
        return "Week of \(week): \(metres.formattedWithGrouping) metres"
    }
}
