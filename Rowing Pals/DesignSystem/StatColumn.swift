//
//  StatColumn.swift
//  Rowing Pals
//

import SwiftUI

/// A small uppercase label over a value — used in feed data strips, profile
/// header stats, and review-sheet totals. The value is always a numeral the
/// user reads, so it stays tabular.
struct StatColumn: View {
    let label: String
    let value: String
    var valueColor: Color = Tokens.Ink.primary
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(valueColor)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        StatColumn(label: "TIME", value: "1:04:50")
        StatColumn(label: "AVG /500M", value: "2:01.6")
        StatColumn(label: "RATE", value: "r19")
    }
    .padding()
    .background(Tokens.Base.ground)
}
