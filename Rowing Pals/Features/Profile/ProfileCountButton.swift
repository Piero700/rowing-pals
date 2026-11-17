//
//  ProfileCountButton.swift
//  Rowing Pals
//

import SwiftUI

/// A Followers or Following count on Profile; opens its list.
struct ProfileCountButton: View {
    let value: Int
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text("\(value)")
                    .textStyle(Typography.cardTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text(label)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minHeight: 48)
            .contentShape(Capsule())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel("\(value) \(label)")
    }
}
