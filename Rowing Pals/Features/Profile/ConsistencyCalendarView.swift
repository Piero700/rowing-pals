//
//  ConsistencyCalendarView.swift
//  Rowing Pals
//

import SwiftUI

/// Design brief (f): a GitHub-style grid, 7 rows (Mon-Sun) by 26 weeks,
/// horizontally scrollable back through the season, shaded in four steps
/// of the cyan ramp by that day's volume, with month labels above.
struct ConsistencyCalendarView: View {
    let days: [ProfileViewModel.ConsistencyDay]

    private static let squareSize: CGFloat = 12
    private static let spacing: CGFloat = 3

    private var byColumn: [Int: [ProfileViewModel.ConsistencyDay]] {
        Dictionary(grouping: days, by: \.column)
    }

    private var columnCount: Int {
        (days.map(\.column).max() ?? -1) + 1
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                monthLabelsRow
                HStack(alignment: .top, spacing: Self.spacing) {
                    ForEach(0..<columnCount, id: \.self) { column in
                        weekColumn(column)
                    }
                }
            }
        }
    }

    private var monthLabelsRow: some View {
        let labels = monthLabelsByColumn()
        return HStack(spacing: Self.spacing) {
            ForEach(0..<columnCount, id: \.self) { column in
                Text(labels[column] ?? "")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.secondary)
                    .frame(width: Self.squareSize, alignment: .leading)
            }
        }
    }

    private func weekColumn(_ column: Int) -> some View {
        VStack(spacing: Self.spacing) {
            ForEach(0..<7, id: \.self) { row in
                square(for: byColumn[column]?.first { $0.row == row })
            }
        }
    }

    private func square(for day: ProfileViewModel.ConsistencyDay?) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(fillColor(shadeLevel: day?.shadeLevel))
            .frame(width: Self.squareSize, height: Self.squareSize)
    }

    private func fillColor(shadeLevel: Int?) -> Color {
        switch shadeLevel {
        case nil: .clear // outside the logged range entirely (a future day)
        case 0: Tokens.Ink.primary.opacity(0.06) // logged range, nothing that day
        case 1: Tokens.Accent.signal.opacity(0.3)
        case 2: Tokens.Accent.signal.opacity(0.6)
        default: Tokens.Accent.signal
        }
    }

    private func monthLabelsByColumn() -> [Int: String] {
        var labels: [Int: String] = [:]
        var lastMonth: Int?
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let calendar = Calendar.current

        for column in 0..<columnCount {
            guard let firstDay = (byColumn[column] ?? []).min(by: { $0.row < $1.row }) else { continue }
            let month = calendar.component(.month, from: firstDay.date)
            if month != lastMonth {
                labels[column] = formatter.string(from: firstDay.date)
                lastMonth = month
            }
        }
        return labels
    }
}
