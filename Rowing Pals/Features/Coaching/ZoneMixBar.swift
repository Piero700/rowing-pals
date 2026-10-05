//
//  ZoneMixBar.swift
//  Rowing Pals
//

import PaceEngine
import SwiftUI

/// The last four weeks' metres by training zone (CoachRower): one 14 pt bar split UT2 … AN in
/// shades of the brand colour, then a legend with each zone's share.
struct ZoneMixBar: View {
    let shares: [CoachingService.ZoneShare]

    var body: some View {
        if shares.isEmpty {
            Text("No zoned erg sessions in the last 4 weeks.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                GeometryReader { geometry in
                    let visible = shares.filter { $0.share > 0 }
                    let gaps = CGFloat(max(visible.count - 1, 0)) * 2
                    HStack(spacing: 2) {
                        ForEach(visible, id: \.zone) { share in
                            Rectangle()
                                .fill(colour(share.zone))
                                .frame(width: max(0, (geometry.size.width - gaps) * share.share))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: Tokens.Size.zoneBar)
                .accessibilityHidden(true)

                WrapLayout(spacing: Tokens.Spacing.tight) {
                    ForEach(shares, id: \.zone) { share in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: Tokens.Coaching.swatchRadius, style: .continuous)
                                .fill(colour(share.zone))
                                .frame(width: Tokens.Size.zoneSwatch, height: Tokens.Size.zoneSwatch)
                            Text(share.zone.rawValue)
                                .textStyle(Typography.meta)
                                .foregroundStyle(Tokens.Ink.primary)
                            Text("\(Int((share.share * 100).rounded()))%")
                                .textStyle(Typography.meta)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                        .padding(.trailing, Tokens.Spacing.tight)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    /// UT2 the full brand colour, each harder zone fainter.
    private func colour(_ zone: Tier.Name) -> Color {
        let order: [Tier.Name] = [.ut2, .ut1, .at, .tr, .an]
        let index = order.firstIndex(of: zone) ?? 0
        let opacity = Tokens.Coaching.zoneOpacities[min(index, Tokens.Coaching.zoneOpacities.count - 1)]
        return Tokens.Accent.brand.mix(with: Tokens.Surface.card, by: 1 - opacity)
    }
}
