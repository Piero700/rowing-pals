//
//  ConsistencyCalendarView.swift
//  Rowing Pals
//

import SwiftUI

/// v3 consistency card contents (`RP Screen.dc.html` §06): a 7-row (Mon–Sun) × 12-week grid of
/// square days — posted = brand, no post = raised with a line border, future days faded to 22 %,
/// today outlined in the records colour — with day letters, a legend and a streak footnote.
struct ConsistencyCalendarView: View {
    let days: [ProfileViewModel.ConsistencyDay]
    /// e.g. "8-day current streak · 1 rest day left this week".
    let footnote: String

    private static let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    private var columns: Int { (days.map(\.column).max() ?? 11) + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Every coloured square is a day you posted a workout.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(Self.dayLetters[row])
                            .font(.system(size: 10))
                            .foregroundStyle(Tokens.Ink.secondary)
                            .frame(width: 16)
                            .frame(maxHeight: .infinity)
                    }
                }
                grid
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                legendItem(fill: Tokens.Surface.raised, border: Tokens.Surface.line, width: 1, label: "No post")
                legendItem(fill: Tokens.Accent.brand, border: Tokens.Accent.brand, width: 1, label: "Posted")
                legendItem(fill: Tokens.Surface.raised, border: Tokens.Accent.records, width: 2, label: "Today")
            }
            .padding(.top, 16)

            Text(footnote)
                .font(.system(size: 11))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 16)
        }
    }

    private var grid: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let lookup = Dictionary(days.map { ("\($0.column)-\($0.row)", $0) }, uniquingKeysWith: { first, _ in first })
        return VStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<columns, id: \.self) { column in
                        cell(lookup["\(column)-\(row)"], today: today)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days.filter { $0.distanceM > 0 }.count) days with a workout in the last 12 weeks")
    }

    @ViewBuilder
    private func cell(_ day: ProfileViewModel.ConsistencyDay?, today: Date) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        let start = day.map { Calendar.current.startOfDay(for: $0.date) }
        let isToday = start == today
        let isFuture = start.map { $0 > today } ?? true
        let posted = (day?.distanceM ?? 0) > 0
        shape
            .fill(posted ? Tokens.Accent.brand : Tokens.Surface.raised)
            .overlay { shape.strokeBorder(posted ? Tokens.Accent.brand : Tokens.Surface.line, lineWidth: 1) }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Tokens.Accent.records, lineWidth: 2)
                        .padding(-3)
                }
            }
            .opacity(isFuture && !isToday ? 0.22 : 1)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    private func legendItem(fill: Color, border: Color, width: CGFloat, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(fill)
                .overlay { RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(border, lineWidth: width) }
                .frame(width: 11, height: 11)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }
}
