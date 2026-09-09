//
//  PillSegmentedControl.swift
//  Rowing Pals
//

import SwiftUI

/// The capsule segmented control used throughout the app — Novice/Senior,
/// Following/My Club/Global, Week/Month/Year, and similar small option sets.
struct PillSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = index == selection
                Text(option)
                    .textStyle(Typography.bodySecondary)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? Tokens.Ink.primary : Tokens.Ink.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Tokens.Ink.primary.opacity(0.16))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selection = index }
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.08))
        }
    }
}

#Preview {
    PillSegmentedControl(options: ["Novice", "Senior"], selection: .constant(0))
        .padding()
        .background(Tokens.Base.ground)
}
