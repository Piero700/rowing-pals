//
//  ProfileSocialRow.swift
//  Rowing Pals
//

import SwiftUI

/// Centred Followers / Following counts (each opens its list), then Find rowers and — on your own
/// profile, when someone is waiting — Follow requests. Another rower's profile starts with a
/// full-width Follow button (v3 §08). The counts are hidden for a locked profile.
struct ProfileSocialRow: View {
    let viewModel: ProfileViewModel
    let isOtherRower: Bool
    @Environment(\.navigate) private var navigate

    var body: some View {
        if isOtherRower {
            FollowButton(
                state: viewModel.followState,
                followsYou: viewModel.followsYou,
                isBusy: viewModel.isFollowBusy,
                variant: .fullWidth
            ) {
                Task { await viewModel.toggleFollow() }
            }
        }
        if !viewModel.isLocked, let userId = viewModel.profileUserId {
            HStack(spacing: 6) {
                ProfileCountButton(value: viewModel.followerCount, label: "Followers") {
                    navigate(.people(.followers(userId)))
                }
                ProfileCountButton(value: viewModel.followingCount, label: "Following") {
                    navigate(.people(.following(userId)))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Spacing.gap)
        }
        if viewModel.isOwnProfile {
            Button("Find rowers") { navigate(.people(.find)) }
                .buttonStyle(.rpText)
                .frame(maxWidth: .infinity)
            if viewModel.pendingRequestCount > 0 {
                Button {
                    navigate(.followRequests)
                } label: {
                    HStack {
                        Text("Follow requests · \(viewModel.pendingRequestCount)")
                            .tabularNumerals()
                        Spacer()
                        RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                    }
                }
                .buttonStyle(.rpGlass)
                .padding(.bottom, Tokens.Spacing.loose)
            }
        }
    }
}
