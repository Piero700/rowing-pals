//
//  BrandChip.swift
//  Rowing Pals
//

import SwiftUI

/// A small brand-tinted label: a set workout's zone ("UT2") or "Test" (CoachWorkouts,
/// RowerFeedCoaching).
struct BrandChip: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(Typography.chip)
            .foregroundStyle(Tokens.Accent.brand)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .frame(minHeight: Tokens.Size.chip)
            .background(Capsule().fill(Tokens.Accent.brandSoft))
    }
}
