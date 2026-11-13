//
//  EffortTrendChart.swift
//  Rowing Pals
//

import Charts
import SwiftUI

/// Average effort per session, week by week for eight weeks (CoachRower; decision 59, user
/// 2026-10-14: "an actual labelled graph", like the PB progression chart). The effort scale 0–10
/// up the side with dashed grid lines, the weeks along the bottom, a filled line with a dot for
/// every week that has ratings, and the four-week average as a labelled dashed line. Tap the
/// chart to read a week; the latest rated week is chosen to start. Red when the engine flags
/// elevated effort, brand otherwise.
struct EffortTrendChart: View {
    /// Oldest first; nil for a week without ratings.
    let weeks: [Double?]
    /// The Monday each of `weeks` starts on.
    let weekStarts: [Date]
    let average: Double?
    let isElevated: Bool

    @State private var selectedIndex: Int?

    /// Effort is rated 1–10; the chart runs from 0 so the lowest rating still sits off the floor.
    private static let domain: ClosedRange<Double> = 0...10
    private static let gridValues: [Double] = [0, 2, 4, 6, 8, 10]

    private static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    private struct Week: Identifiable {
        let id: Int
        let start: Date
        let effort: Double?
    }

    private var data: [Week] {
        zip(weekStarts, weeks).enumerated().map { Week(id: $0.offset, start: $0.element.0, effort: $0.element.1) }
    }

    private var line: Color { isElevated ? Tokens.System.error : Tokens.Accent.brand }
    private var area: Color { isElevated ? Tokens.System.errorSoft : Tokens.Accent.brandSoft }

    /// The chosen week, or the latest one with ratings.
    private var chosen: Week? {
        if let selectedIndex, let week = data.first(where: { $0.id == selectedIndex }) { return week }
        return data.last { $0.effort != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            Text("Effort · 1 easy to 10 all-out")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
            chart
                .frame(height: Tokens.Size.effortChart)
            if let chosen {
                chosenPanel(chosen)
            }
            Text("Tap the chart to see each week.")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity)
                .guidance()
        }
    }

    private var chart: some View {
        let rated = data.filter { $0.effort != nil }
        let chosen = self.chosen
        return Chart {
            ForEach(rated) { week in
                AreaMark(
                    x: .value("Week", week.start),
                    yStart: .value("Floor", Self.domain.lowerBound),
                    yEnd: .value("Effort", week.effort ?? 0)
                )
                .foregroundStyle(area)
                LineMark(x: .value("Week", week.start), y: .value("Effort", week.effort ?? 0))
                    .foregroundStyle(line)
                    .lineStyle(StrokeStyle(lineWidth: Tokens.Coaching.effortLine, lineCap: .round, lineJoin: .round))
            }
            if let average {
                RuleMark(y: .value("4-week average", average))
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                    // Under the line when it's high, so it doesn't run into the "10".
                    .annotation(position: average > 7 ? .bottom : .top, alignment: .leading, spacing: 2) {
                        Text(String(format: "4-week avg %.1f", average))
                            .textStyle(Typography.statLabel)
                            .monospacedDigit()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
            }
            if let chosen {
                RuleMark(x: .value("Chosen", chosen.start))
                    .foregroundStyle(line)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            ForEach(rated) { week in
                let isChosen = week.id == chosen?.id
                let diameter = (isChosen ? Tokens.Coaching.effortDotLatest : Tokens.Coaching.effortDot) * 2.6
                PointMark(x: .value("Week", week.start), y: .value("Effort", week.effort ?? 0))
                    .symbol {
                        Circle()
                            .fill(isChosen ? line : Tokens.Surface.card)
                            .overlay { Circle().strokeBorder(line, lineWidth: 2) }
                            .frame(width: diameter, height: diameter)
                    }
            }
        }
        .chartYScale(domain: Self.domain)
        .chartXScale(domain: xDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: Self.gridValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    .foregroundStyle(Tokens.Surface.line)
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text("\(Int(raw))")
                            .textStyle(Typography.meta)
                            .monospacedDigit()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: labelledWeeks) { value in
                AxisValueLabel(anchor: anchor(for: value.as(Date.self))) {
                    if let date = value.as(Date.self) {
                        Text(label(for: date))
                            .textStyle(Typography.meta)
                            .monospacedDigit()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    // A tap, not a drag, so the page still scrolls over the chart.
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { tap in select(nearest: tap.location, proxy: proxy, geometry: geometry) }
                    )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Effort trend, 8 weeks")
        .accessibilityValue(accessibilityText)
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = weekStarts.first, let last = weekStarts.last, first < last else {
            let only = weekStarts.first ?? Date()
            return only.addingTimeInterval(-86_400 * 7)...only.addingTimeInterval(86_400 * 7)
        }
        return first...last
    }

    /// Every third week back from this one, so this week is always labelled and no two labels
    /// run together.
    private var labelledWeeks: [Date] {
        stride(from: weekStarts.count - 1, through: 0, by: -3).map { weekStarts[$0] }.reversed()
    }

    private func label(for date: Date) -> String {
        date == weekStarts.last ? "This week" : Self.weekFormatter.string(from: date)
    }

    /// The edge labels sit inside the plot so they aren't clipped.
    private func anchor(for date: Date?) -> UnitPoint {
        if date == weekStarts.last { return .topTrailing }
        if date == weekStarts.first { return .topLeading }
        return .top
    }

    /// Tap: the week nearest in time becomes the chosen one.
    private func select(nearest location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = location.x - geometry[plotFrame].origin.x
        guard let date: Date = proxy.value(atX: x) else { return }
        selectedIndex = data.min { abs($0.start.timeIntervalSince(date)) < abs($1.start.timeIntervalSince(date)) }?.id
    }

    /// Raised panel: the chosen week and its average effort.
    private func chosenPanel(_ week: Week) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(week.start == weekStarts.last ? "This week" : "Week of \(Self.weekFormatter.string(from: week.start))")
                    .textStyle(Typography.detail)
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Average effort per session")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Text(week.effort.map { String(format: "%.1f / 10", $0) } ?? "No ratings")
                .textStyle(Typography.rowTitle)
                .monospacedDigit()
                .foregroundStyle(week.effort == nil ? Tokens.Ink.secondary : line)
        }
        .padding(.horizontal, Tokens.Spacing.loose)
        .padding(.vertical, Tokens.Spacing.tight)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous).fill(Tokens.Surface.raised))
        .accessibilityElement(children: .combine)
    }

    private var accessibilityText: String {
        guard let chosen else { return "No effort ratings" }
        let effort = chosen.effort.map { String(format: "%.1f out of 10", $0) } ?? "no ratings"
        return "\(label(for: chosen.start)), \(effort)"
    }
}
