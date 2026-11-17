//
//  ProfileStatsCard.swift
//  Rowing Pals
//

import SwiftUI

/// Profile's 4-up card (weekly volume, sessions, PBs, streak days on your own; v3 §08's figures on
/// another rower's): value 21 bold over a 10 pt label, thin dividers between columns.
struct ProfileStatsCard: View {
    struct Stat {
        let value: String
        let label: String
    }

    let stats: [Stat]

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(stats.indices, id: \.self) { index in
                VStack(spacing: 2) {
                    Text(stats[index].value)
                        .font(.system(size: 22, weight: .semibold))
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(stats[index].label)
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                if index < stats.count - 1 {
                    Rectangle().fill(Tokens.Surface.line).frame(width: 1, height: 30)
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.loose)
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    /// "116.3k" — thousands of metres, as the v3 stats card writes it.
    static func compactMetres(_ metres: Int) -> String {
        guard metres >= 1_000 else { return "\(metres)" }
        return String(format: "%.1fk", Double(metres) / 1_000)
    }

    /// "#5", or a dash with nothing to rank.
    static func rankText(_ rank: Int?) -> String {
        rank.map { "#\($0)" } ?? "—"
    }
}
