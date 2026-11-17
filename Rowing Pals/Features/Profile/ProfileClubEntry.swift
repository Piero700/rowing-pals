//
//  ProfileClubEntry.swift
//  Rowing Pals
//

import SwiftUI

/// The v2 prototype's club entry on Profile (decision 25): admins and up manage the club; members
/// see their club; rowers without a club join or create one. A pending request and any invitations
/// show beneath.
struct ProfileClubEntry: View {
    let viewModel: ProfileViewModel
    @Environment(\.navigate) private var navigate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProfileSectionTitle(text: "Club")
            Button(title) {
                navigate(viewModel.clubRole?.canManageMembers == true ? .manageClub : .clubHub)
            }
            .buttonStyle(.rpGlass)
            if let pending = viewModel.pendingClubName {
                Text("Join request pending · \(pending)")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 2)
            }
            ForEach(viewModel.invitingClubNames, id: \.self) { club in
                Button {
                    navigate(.clubHub)
                } label: {
                    Text("\(club) invited you to join · View")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Accent.brand)
                        .frame(minHeight: Tokens.Size.minTap)
                }
                .buttonStyle(IconPressStyle())
                .padding(.horizontal, 2)
            }
        }
    }

    private var title: String {
        switch viewModel.clubRole {
        case .none: "Join or create a club"
        case .member?: "Your club"
        default: "Manage your club"
        }
    }
}
