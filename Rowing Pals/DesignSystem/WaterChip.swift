//
//  WaterChip.swift
//  Rowing Pals
//

import SwiftUI

/// A small brand chip with waves, for anything on the water (CoachBoats, RowerBoat): "Water", or a
/// boat's type ("4−").
struct WaterChip: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "water.waves")
                .imageScale(.small)
            Text(text)
                .monospacedDigit()
        }
        .textStyle(Typography.chip)
        .foregroundStyle(Tokens.Accent.brand)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 2)
        .frame(minHeight: Tokens.Size.chip)
        .background(Capsule().fill(Tokens.Accent.brandSoft))
    }
}
