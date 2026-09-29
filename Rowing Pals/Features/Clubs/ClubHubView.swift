//
//  ClubHubView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 12 — "Your crew", to v3 §12 (`docs/design/v3/RP Screen.dc.html`): your club's name
/// and "Join an existing crew, start your own, or row independently.", then Find a club to
/// join, Create a club and Continue without a club. Decision 25 adds what the design's
/// prototype does around it: your role and Manage club for admins and up, a pending join
/// request you can cancel, and club invitations to accept or decline.
struct ClubHubView: View {
    @State private var viewModel = ClubHubViewModel()
    @State private var isConfirmingLeave = false
    @Environment(\.navigate) private var navigate
    @Environment(\.dismiss) private var dismiss

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                header

                if let membership = viewModel.membership {
                    if membership.role.canManageMembers, membership.club != nil {
                        Button("Manage club") { navigate(.manageClub) }
                            .buttonStyle(.rpGlass)
                    }
                    if let pending = membership.pendingRequest {
                        pendingCard(pending)
                    }
                    if !membership.invitations.isEmpty {
                        invitations(membership.invitations)
                    }
                }

                Button("Find a club to join") { navigate(.findClub) }
                    .buttonStyle(.rpPrimary)
                Button("Create a club") { navigate(.createClub) }
                    .buttonStyle(.rpGlass)
                Button("Continue without a club") {
                    if viewModel.membership?.club != nil {
                        isConfirmingLeave = true
                    } else {
                        dismiss()
                    }
                }
                .buttonStyle(.rpText)
                .frame(maxWidth: .infinity)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Your crew") { dismiss() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Tokens.Base.ground)
        .disabled(viewModel.isWorking)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.load() }
        }
        .alert("Leave \(viewModel.membership?.club?.name ?? "your club")?", isPresented: $isConfirmingLeave) {
            Button("Leave", role: .destructive) { Task { await viewModel.leave() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your sessions, metres and PBs stay yours. You can join a club again any time.")
        }
    }

    /// v3: the club's name at 23 pt, then one muted line; decision 25 adds the details.
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.membership?.club?.name ?? (viewModel.isLoading ? " " : "No club yet"))
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.top, 6)
            if let membership = viewModel.membership, let club = membership.club {
                Text(clubMeta(club, membership: membership))
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Text("Join an existing crew, start your own, or row independently.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 2)
    }

    private func clubMeta(_ club: Club, membership: ClubService.Membership) -> String {
        var parts = ["\(membership.memberCount) member\(membership.memberCount == 1 ? "" : "s")"]
        if let location = club.location, !location.isEmpty { parts.append(location) }
        parts.append(club.joinPolicy.tag)
        parts.append("You're \(membership.role == .member ? "a member" : "the \(membership.role.label.lowercased())")")
        return parts.joined(separator: " · ")
    }

    /// The prototype's "Join request pending · <club>", with a way to take it back.
    private func pendingCard(_ club: Club) -> some View {
        HStack(spacing: Tokens.Spacing.gap) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Join request pending")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(club.name)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer(minLength: 0)
            Button("Cancel") { Task { await viewModel.cancelRequest() } }
                .buttonStyle(.rpPill(isOn: false))
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func invitations(_ clubs: [Club]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Invitations")
            VStack(spacing: 0) {
                ForEach(Array(clubs.enumerated()), id: \.element.id) { index, club in
                    HStack(spacing: Tokens.Spacing.gap) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(club.name)
                                .textStyle(Typography.name)
                                .foregroundStyle(Tokens.Ink.primary)
                            Text("invited you to join")
                                .textStyle(Typography.meta)
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                        Spacer(minLength: 0)
                        Button("Decline") { Task { await viewModel.respond(to: club, accept: false) } }
                            .buttonStyle(.rpText)
                        Button("Join") { Task { await viewModel.respond(to: club, accept: true) } }
                            .buttonStyle(.rpPill(isOn: true))
                    }
                    .padding(12)
                    if index < clubs.count - 1 {
                        Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                    }
                }
            }
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .clipShape(Self.cardShape)
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        }
    }
}
