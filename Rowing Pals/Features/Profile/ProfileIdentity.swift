//
//  ProfileIdentity.swift
//  Rowing Pals
//

import SwiftUI

/// Centred 76 pt avatar (with a 32 pt streak badge), name 23 bold, "Club · Level" 13 muted. Another
/// rower's profile (v3 §08) shows the club alone, then whether the profile is public.
struct ProfileIdentity: View {
    let viewModel: ProfileViewModel
    let isOtherRower: Bool

    var body: some View {
        VStack(spacing: 0) {
            ProfileAvatar(viewModel: viewModel, isOtherRower: isOtherRower)
                .padding(.bottom, Tokens.Spacing.gap)
            Text(viewModel.displayName)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
                .multilineTextAlignment(.center)
            if let username = viewModel.username {
                Text("@\(username)")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.top, 2)
            }
            // The club, with its verified tag (decision 98), then the level on your own profile.
            HStack(spacing: Tokens.Spacing.verifiedGap) {
                ClubNameLabel(name: viewModel.clubName ?? "No club",
                              isVerified: viewModel.clubName != nil && viewModel.clubIsVerified,
                              badgeSize: Tokens.Icon.badge)
                if let level {
                    Text("· \(level)")
                }
            }
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 4)
                .padding(.bottom, isOtherRower ? 0 : 8)
            if isOtherRower {
                // v3 §08: the club on one line, whether the profile is public on the next.
                Text(viewModel.isPrivateAccount ? "Private profile" : "Public profile")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, Tokens.Spacing.tight)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Spacing.loose)
        .padding(.bottom, 14)
    }

    /// Your own profile: "Club · Level". Another rower's (v3 §08), or a coach-only account's
    /// (no level, decision 34): the club alone.
    private var level: String? {
        if isOtherRower || !viewModel.isRower { return nil }
        let level = viewModel.categoryLabel.capitalized
        return level.isEmpty ? nil : level
    }
}
