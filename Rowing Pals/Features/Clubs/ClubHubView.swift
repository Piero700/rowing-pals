//
//  ClubHubView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 12 — "Your crew", to v3 §12 (`docs/design/v3/RP Screen.dc.html`), shaped by decisions
/// 25–26. **In a club** (one club at a time): the club — name, details, your role — and every
/// other member, each opening their profile; Manage club for admins and up; and the one way out,
/// Leave club (an owner hands over or deletes in Manage club instead). **Without a club**:
/// your join request — "Requested" while it waits, or that you weren't accepted with Request
/// again — any invitations, then v3's Find a club to join, Create a club and Continue without
/// a club. The page updates live; when a waiting request is accepted it closes, back to where
/// you started.
struct ClubHubView: View {
    @State private var viewModel = ClubHubViewModel()
    @State private var isConfirmingLeave = false
    @Environment(\.navigate) private var navigate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.closeRoute) private var closeRoute
    @Environment(\.scenePhase) private var scenePhase

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let membership = viewModel.membership {
                    if let club = membership.club {
                        inClub(club, membership: membership)
                    } else {
                        withoutClub(membership)
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.top, Tokens.Spacing.loose)
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
        .task {
            for await _ in ClubLiveUpdates.changes() { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.load() } }
        }
        .onChange(of: viewModel.wasAccepted) { _, accepted in
            if accepted { closeRoute() }
        }
        .alert("Leave \(viewModel.membership?.club?.name ?? "your club")?", isPresented: $isConfirmingLeave) {
            Button("Leave", role: .destructive) { Task { await viewModel.leave() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your sessions, metres and PBs stay yours. You can join a club again any time.")
        }
    }

    // MARK: - In a club

    @ViewBuilder
    private func inClub(_ club: Club, membership: ClubService.Membership) -> some View {
        clubCard(club, membership: membership)
            .padding(.top, 6)

        if membership.role.canManageMembers {
            Button("Manage club") { navigate(.manageClub) }
                .buttonStyle(.rpGlass)
                .padding(.top, Tokens.Spacing.loose)
        }

        SectionTitle("Crewmates · \(crewmates.count)")
        membersCard

        VStack(alignment: .leading, spacing: 6) {
            if membership.role == .owner {
                Text("You own this club. To leave it, hand it over to another member or delete it in Manage club.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            } else {
                Button("Leave club") { isConfirmingLeave = true }
                    .buttonStyle(.rpDestructive)
            }
        }
        .padding(.top, Tokens.Spacing.sectionTop)
    }

    /// The club: name, description, members, place, join rule, focus and your role.
    private func clubCard(_ club: Club, membership: ClubService.Membership) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(membership.role == .member ? "You're a member" : "You're the \(membership.role.label.lowercased())")
                .textStyle(Typography.overline)
                .foregroundStyle(Tokens.Accent.brand)
            Text(club.name)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
            if let description = club.description, !description.isEmpty {
                Text(description)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            WrapLayout(spacing: Tokens.Spacing.tight) {
                tag("\(membership.memberCount) member\(membership.memberCount == 1 ? "" : "s")")
                if let location = club.location, !location.isEmpty { tag(location) }
                tag(club.joinPolicy.tag)
                tag(club.focus.rawValue)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.card + 3)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.statLabel)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Tokens.Surface.raised))
            .lineLimit(1)
    }

    /// Everyone in the club but you (user, 2026-10-04).
    private var crewmates: [ClubService.Person] {
        viewModel.members.filter { $0.id != viewModel.myId }
    }

    /// Everyone else in the club — owner first, then co-owners, admins, members — each opening
    /// their profile.
    @ViewBuilder
    private var membersCard: some View {
        if crewmates.isEmpty {
            Text("Nobody else is in the club yet.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Tokens.Spacing.card)
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        } else {
            crewmatesList
        }
    }

    private var crewmatesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(crewmates.enumerated()), id: \.element.id) { index, person in
                HStack(spacing: Tokens.Spacing.gap) {
                    AvatarPlaceholder(diameter: 38, name: person.displayName, userId: person.id)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(person.displayName)
                            .textStyle(Typography.name)
                            .foregroundStyle(Tokens.Ink.primary)
                            .lineLimit(1)
                        Text(person.role == .member
                             ? person.category.rawValue.capitalized
                             : "\(person.role.label) · \(person.category.rawValue.capitalized)")
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .padding(12)
                .asButton { navigate(.profile(person.id)) }
                .accessibilityElement(children: .combine)
                if index < crewmates.count - 1 {
                    Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                }
            }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .clipShape(Self.cardShape)
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    // MARK: - Without a club

    @ViewBuilder
    private func withoutClub(_ membership: ClubService.Membership) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No club yet")
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
            Text("Join an existing crew, start your own, or row independently.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(.horizontal, 2)
        .padding(.top, 6)
        .padding(.bottom, 14)

        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            if let request = membership.request {
                requestCard(request)
            }
            if !membership.invitations.isEmpty {
                invitations(membership.invitations)
            }
            Button("Find a club to join") { navigate(.findClub) }
                .buttonStyle(.rpPrimary)
            Button("Create a club") { navigate(.createClub) }
                .buttonStyle(.rpGlass)
            Button("Continue without a club") { dismiss() }
                .buttonStyle(.rpText)
                .frame(maxWidth: .infinity)
        }
    }

    /// Waiting: "Requested" (greyed) with Refresh and Cancel request. Declined: "You weren't
    /// accepted" with Request again and Dismiss.
    private func requestCard(_ request: ClubService.JoinRequest) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.gap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.isDeclined ? "You weren't accepted to \(request.club.name)" : "Request sent to \(request.club.name)")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(request.isDeclined ? Tokens.System.error : Tokens.Ink.primary)
                Text(request.isDeclined
                     ? "An admin declined your request. You can ask again, or find another club."
                     : "You'll join as soon as an admin accepts. This page updates by itself.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            HStack(spacing: Tokens.Spacing.tight) {
                if request.isDeclined {
                    Button("Request again") { Task { await viewModel.requestAgain(request.club) } }
                        .buttonStyle(.rpPill(isOn: true))
                    Button("Dismiss") { Task { await viewModel.cancelRequest() } }
                        .buttonStyle(.rpText)
                } else {
                    Button("Requested") {}
                        .buttonStyle(.rpPill(isOn: false))
                        .disabled(true)
                        .opacity(0.5)
                    Button("Refresh") { Task { await viewModel.load() } }
                        .buttonStyle(.rpText)
                    Spacer(minLength: 0)
                    Button("Cancel request") { Task { await viewModel.cancelRequest() } }
                        .buttonStyle(.rpText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
