//
//  WeeklyVolumeChart.swift
//  Rowing Pals
//

import SwiftUI

/// v3 weekly volume card contents (`RP Screen.dc.html` §06): the selected week's total (this
/// week by default, "In progress"), 12 bars — this week in the records colour, the rest brand at
/// 65 % — on a 0 / half / max axis, and first / middle / last week dates. Tapping a bar shows that
/// week's total in the header ("Tap a bar for the total"). Always metres (decision 3).
struct WeeklyVolumeChart: View {
    let weeks: [ProfileViewModel.WeeklyVolume]

    @State private var selectedWeek: Date?

    private static let chartHeight: CGFloat = 156

    private var shownWeek: ProfileViewModel.WeeklyVolume? {
        weeks.first { $0.weekStart == selectedWeek } ?? weeks.first(where: \.isCurrentWeek) ?? weeks.last
    }

    /// A round axis top above the busiest week: 1, 2, 2.5 or 5 × a power of ten.
    private var axisMax: Int {
        let peak = max(weeks.map(\.distanceM).max() ?? 0, 1_000)
        let magnitude = pow(10, floor(log10(Double(peak))))
        let step = [1.0, 2.0, 2.5, 5.0, 10.0].first { $0 * magnitude >= Double(peak) } ?? 10
        return Int(step * magnitude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HStack(alignment: .bottom, spacing: 8) {
                yAxis
                bars
            }
            .frame(height: Self.chartHeight)
            .padding(.top, 22)
            xAxis
                .padding(.top, 8)
                .padding(.leading, 41)
            Text("Monday–Sunday · Tap a bar for the total")
                .font(.system(size: 11))
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 15)
        }
    }

    private var header: some View {
        let week = shownWeek
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(week.map { $0.isCurrentWeek ? "This week · In progress" : "Week of \(Self.dayMonth($0.weekStart))" } ?? "This week")
                    .textStyle(Typography.overline)
                    .foregroundStyle(Tokens.Ink.secondary)
                (Text((week?.distanceM ?? 0).formattedWithGrouping)
                    + Text(" m").font(.system(size: 15, weight: .medium)).foregroundColor(Tokens.Ink.secondary))
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.7)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
            }
            Spacer(minLength: 8)
            if let week {
                Text(Self.dayMonth(week.weekStart))
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var yAxis: some View {
        VStack(alignment: .leading) {
            Text(Self.compact(axisMax))
            Spacer(minLength: 0)
            Text(Self.compact(axisMax / 2))
            Spacer(minLength: 0)
            Text("0")
        }
        .font(.system(size: 10))
        .tabularNumerals()
        .foregroundStyle(Tokens.Ink.secondary)
        .frame(width: 33, alignment: .leading)
        .accessibilityHidden(true)
    }

    private var bars: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(weeks) { week in
                    let fraction = CGFloat(week.distanceM) / CGFloat(axisMax)
                    let isShown = week.weekStart == shownWeek?.weekStart
                    Button {
                        selectedWeek = week.weekStart
                    } label: {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                                .fill(week.isCurrentWeek ? Tokens.Accent.records : Tokens.Accent.brand)
                                .opacity(week.isCurrentWeek ? 1 : 0.65)
                                .overlay(alignment: .top) {
                                    if isShown && !week.isCurrentWeek {
                                        UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                                            .strokeBorder(Tokens.Ink.primary, lineWidth: 1.5)
                                    }
                                }
                                .frame(height: max(geometry.size.height * fraction, week.distanceM > 0 ? 3 : 0))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Week of \(Self.dayMonth(week.weekStart)), \(week.distanceM.formattedMetres)")
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Surface.line).frame(height: 1)
        }
    }

    private var xAxis: some View {
        HStack {
            if let first = weeks.first { Text(Self.dayMonth(first.weekStart)) }
            Spacer(minLength: 0)
            if weeks.count > 2 { Text(Self.dayMonth(weeks[weeks.count / 2].weekStart)) }
            Spacer(minLength: 0)
            if let last = weeks.last { Text(Self.dayMonth(last.weekStart)) }
        }
        .font(.system(size: 10))
        .foregroundStyle(Tokens.Ink.secondary)
        .accessibilityHidden(true)
    }

    /// "14 Sept" (UK style).
    static func dayMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    /// Axis labels: "125k", "62.5k", "900".
    private static func compact(_ metres: Int) -> String {
        guard metres >= 1_000 else { return "\(metres)" }
        let thousands = Double(metres) / 1_000
        return thousands.rounded() == thousands ? "\(Int(thousands))k" : String(format: "%.1fk", thousands)
    }
}
