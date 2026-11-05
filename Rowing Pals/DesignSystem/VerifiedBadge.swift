//
//  VerifiedBadge.swift
//  Rowing Pals
//

import SwiftUI

/// The verified tag (decision 98): a small shield with a tick beside a club's name, in
/// `Accent.verified`, so people joining can tell which club is the real one. Only clubs you've
/// approved in the database carry it.
struct VerifiedBadge: View {
    var size: CGFloat = Tokens.Icon.chip

    var body: some View {
        RPIconView(icon: .verified, size: size, weight: Tokens.Icon.verifiedStroke)
            .foregroundStyle(Tokens.Accent.verified)
            .accessibilityHidden(false)
            .accessibilityLabel("Verified club")
    }
}

/// A club's name with the verified tag after it when the club is verified. Style the text as the
/// place it sits needs (`.textStyle`, `.foregroundStyle`); the tag keeps its own colour.
struct ClubNameLabel: View {
    let name: String
    let isVerified: Bool
    var badgeSize: CGFloat = Tokens.Icon.chip

    var body: some View {
        HStack(spacing: Tokens.Spacing.verifiedGap) {
            Text(name)
            if isVerified {
                VerifiedBadge(size: badgeSize)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
