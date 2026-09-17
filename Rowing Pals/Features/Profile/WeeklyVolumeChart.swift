//
//  WeeklyVolumeChart.swift
//  Rowing Pals
//

import Charts
import SwiftUI

/// Twelve weeks of metres, design brief (e): current week in cyan, past
/// weeks muted, the rower's weekly target as a dashed line across the
/// whole chart. "The honest counterpart to the streak — gaps are visible
/// instantly," so this deliberately does *not* hide a zero week; a bar
/// chart's baseline has to stay at zero for the bar heights to mean
/// anything, unlike the PB progression line chart's zoomed axis.
struct WeeklyVolumeChart: View {
    let weeks: [ProfileViewModel.WeeklyVolume]
    let targetM: Int

    var body: some View {
        Chart {
            ForEach(weeks) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Metres", week.distanceM)
                )
                .foregroundStyle(week.isCurrentWeek ? Tokens.Accent.brand : Tokens.Ink.primary.opacity(0.22))
                .cornerRadius(3)
            }
            if targetM > 0 {
                RuleMark(y: .value("Target", targetM))
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(Int.self) {
                        Text(raw.formattedWithGrouping)
                            .tabularNumerals()
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .frame(height: 160)
    }
}
