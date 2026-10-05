//
//  EffortTrendChart.swift
//  Rowing Pals
//

import SwiftUI

/// Average effort per session, week by week for eight weeks (CoachRower): a line with a dot per
/// week that has ratings — the latest larger — over a dashed line at the four-week average.
/// Red when the engine flags elevated effort, ink otherwise.
struct EffortTrendChart: View {
    /// Oldest first; nil for a week without ratings.
    let weeks: [Double?]
    let average: Double?
    let isElevated: Bool

    /// Effort is rated 1–10; the chart spans that.
    private static let range: ClosedRange<Double> = 1...10

    var body: some View {
        let colour = isElevated ? Tokens.System.error : Tokens.Ink.primary
        GeometryReader { geometry in
            let points = points(in: geometry.size)
            ZStack {
                if let average {
                    Path { path in
                        let y = y(for: average, height: geometry.size.height)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Tokens.Ink.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                }
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(colour, style: StrokeStyle(lineWidth: Tokens.Coaching.effortLine, lineCap: .round, lineJoin: .round))
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    let isLatest = index == points.count - 1
                    let radius = isLatest ? Tokens.Coaching.effortDotLatest : Tokens.Coaching.effortDot
                    Circle()
                        .fill(isLatest ? colour : Tokens.Surface.card)
                        .overlay { Circle().strokeBorder(colour, lineWidth: 2) }
                        .frame(width: radius * 2, height: radius * 2)
                        .position(point)
                }
            }
        }
        .frame(height: Tokens.Size.effortChart)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let inset = Tokens.Coaching.effortDotLatest + 2
        let step = weeks.count > 1 ? (size.width - inset * 2) / CGFloat(weeks.count - 1) : 0
        return weeks.enumerated().compactMap { index, value in
            value.map { CGPoint(x: inset + step * CGFloat(index), y: y(for: $0, height: size.height)) }
        }
    }

    private func y(for value: Double, height: CGFloat) -> CGFloat {
        let inset = Tokens.Coaching.effortDotLatest + 2
        let clamped = min(max(value, Self.range.lowerBound), Self.range.upperBound)
        let fraction = (clamped - Self.range.lowerBound) / (Self.range.upperBound - Self.range.lowerBound)
        return inset + (height - inset * 2) * CGFloat(1 - fraction)
    }

    private var accessibilityText: String {
        let rated = weeks.compactMap { $0 }
        guard let last = rated.last else { return "No effort ratings" }
        return String(format: "Effort over 8 weeks, latest week %.1f out of 10", last)
    }
}
