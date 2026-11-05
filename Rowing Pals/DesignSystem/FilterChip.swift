//
//  FilterChip.swift
//  Rowing Pals
//

import SwiftUI

/// A single pill chip — Male/Female, segment tags
/// (Warmup/Main/Cooldown/Extra), distance tags.
struct FilterChip: View {
    let label: String
    var isSelected: Bool = false

    var body: some View {
        // A fixed size for every chip, rather than per-chip auto-shrink, so
        // short and long labels (MAIN vs. COOLDOWN) read at the same size.
        Text(label)
            .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
            .tracking(0.4)
            .tabularNumerals()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(isSelected ? Tokens.Ink.primary : Tokens.Ink.secondary)
            .padding(.horizontal, Tokens.Spacing.gap)
            .padding(.vertical, Tokens.Spacing.tight)
            .background {
                RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
                    .fill(Tokens.Ink.primary.opacity(isSelected ? 0.16 : 0.07))
            }
    }
}

#Preview {
    HStack {
        FilterChip(label: "Male", isSelected: true)
        FilterChip(label: "Female")
    }
    .padding()
    .background(Tokens.Base.ground)
}
