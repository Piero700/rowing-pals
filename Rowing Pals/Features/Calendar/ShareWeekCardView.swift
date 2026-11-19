//
//  ShareWeekCardView.swift
//  Rowing Pals
//

import SwiftUI

/// The picture a coach shares to WhatsApp (decision 110): a week ("This week", "Novice men ·
/// 23–29 Nov") or one workout (its title, "Wed 25 Nov · 06:30"). Always drawn in the dark
/// palette, fixed width, height from the rows. Rendered at 3x (1080 px wide).
struct ShareWeekCardView: View {
    let heading: String
    let subheading: String
    let rows: [ShareCardRow]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .textStyle(Typography.profileName)
                    .foregroundStyle(Tokens.Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subheading)
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            if rows.isEmpty {
                Text("Nothing planned yet")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(Tokens.ShareWeek.rowPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Tokens.Surface.card, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
            } else {
                VStack(spacing: Tokens.ShareWeek.rowSpacing) {
                    ForEach(rows) { ShareCardRowView(row: $0) }
                }
            }
            ShareCardFooter()
        }
        .padding(Tokens.ShareWeek.margin)
        .frame(width: Tokens.ShareWeek.width, alignment: .leading)
        .background(Tokens.Base.ground)
        .environment(\.colorScheme, .dark)
    }
}
