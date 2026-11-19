//
//  ShareCardRowView.swift
//  Rowing Pals
//

import SwiftUI

/// One row on the shared week or workout picture: day and time in brand blue on the left,
/// title and detail on the right.
struct ShareCardRowView: View {
    let row: ShareCardRow

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.loose) {
            if !row.dayText.isEmpty || row.timeText != nil {
                VStack(alignment: .leading, spacing: Tokens.ShareWeek.lineGap) {
                    if !row.dayText.isEmpty {
                        Text(row.dayText)
                            .textStyle(Typography.rowTitle)
                            .tabularNumerals()
                    }
                    if let time = row.timeText {
                        Text(time)
                            .textStyle(Typography.meta)
                            .tabularNumerals()
                    }
                }
                .foregroundStyle(Tokens.Accent.brand)
                .frame(width: Tokens.ShareWeek.dayColumn, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: Tokens.ShareWeek.lineGap) {
                Text(row.title)
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = row.detail {
                    Text(detail)
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Tokens.ShareWeek.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Surface.card, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
    }
}
