//
//  EstimateCard.swift
//  Rowing Pals
//

import SwiftUI

/// v3's "2k · Estimated today" card (Profile §06, PB history §10): records-soft fill, 30 %
/// records edge, radius 22. The number waits for the user's own prediction algorithm
/// (docs/design/v2-decisions.md #2) — until then it shows a dash and says so.
struct EstimateCard: View {
    let label: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.estimate, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer()
                Image(systemName: "info.circle")
                    .foregroundStyle(Tokens.Accent.records)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
            }
            Text("—")
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(Tokens.Accent.records)
            Text("Your estimate will appear here once the prediction algorithm is added.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.vertical, 6)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(shape.fill(Tokens.Accent.recordsSoft))
        .overlay { shape.strokeBorder(Tokens.Accent.records.opacity(0.3), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}
