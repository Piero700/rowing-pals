//
//  ManageClubView.swift
//  Rowing Pals
//

import SwiftUI

/// Manage club — the prototype's `manage-club` (docs/design/rowing-pals-redesign-handoff-v2.md
/// §12), open to admins, co-owners and the owner (decision 25): a summary with your role and
/// the join rule; Edit club (co-owners and up); join requests to accept or decline; Invite a
/// rower and the club's invite code; pending invitations; members with their roles, each
/// managed from a sheet; and, for the owner, Hand over ownership and Delete club — anyone else
/// can Leave club.
struct ManageClubView: View {
    @State private var viewModel = ManageClubViewModel()
    @State private var managedPerson: ClubService.Person?
    @State private var isChoosingNewOwner = false
    @State private var newOwner: ClubService.Person?
    @State private var isConfirmingDelete = false
    @State private var isConfirmingLeave = false
    @State private var isConfirmingNewCode = false
    @Environment(\.navigate) private var navigate
    @Environment(\.dismiss) private var dismiss

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let club = viewModel.club, viewModel.myRole.canManageMembers {
                    summary(club)
                    if viewModel.myRole.canEditClub {
                        Button("Edit club") { navigate(.editClub) }
                            .buttonStyle(.rpGlass)
                            .padding(.top, Tokens.Spacing.loose)
                    }
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.System.error)
                            .padding(.top, Tokens.Spacing.loose)
                    }
                    requestsSection
                    inviteSection(club)
                    membersSection
                    ownershipSection(club)
                } else if !viewModel.isLoading {
                    Text(viewModel.errorMessage ?? "Only admins, co-owners and the owner can manage the club.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Manage club") { dismiss() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Tokens.Base.ground)
        .disabled(viewModel.isWorking)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.load() }
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { dismiss() }
        }
        .sheet(item: $managedPerson) { person in
            ClubMemberSheet(
                person: person,
                myRole: viewModel.myRole,
                onSetRole: { role in Task { await viewModel.setRole(role, for: person) } },
                onRemove: { Task { await viewModel.remove(person) } }
            )
            .presentationDetents([.medium])
        }
        .confirmationDialog("Hand over ownership to…", isPresented: $isChoosingNewOwner, titleVisibility: .visible) {
            ForEach(viewModel.otherMembers) { person in
                Button(person.displayName) { newOwner = person }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Make \(newOwner?.displayName ?? "them") the owner?", isPresented: Binding(
            get: { newOwner != nil }, set: { if !$0 { newOwner = nil } }
        )) {
            Button("Hand over") {
                if let person = newOwner { Task { await viewModel.transferOwnership(to: person) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They'll run the club. You'll stay on as a co-owner and can leave afterwards.")
        }
        .alert("Delete \(viewModel.club?.name ?? "the club")?", isPresented: $isConfirmingDelete) {
            Button("Delete club", role: .destructive) { Task { await viewModel.deleteClub() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everyone in it will be left without a club. Their sessions, metres and PBs stay theirs. This can't be undone.")
        }
        .alert("Leave \(viewModel.club?.name ?? "the club")?", isPresented: $isConfirmingLeave) {
            Button("Leave", role: .destructive) { Task { await viewModel.leave() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Make a new invite code?", isPresented: $isConfirmingNewCode) {
            Button("New code") { Task { await viewModel.newInviteCode() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The old code will stop working.")
        }
    }

    // MARK: - Summary

    /// The prototype's summary card: "You are the owner", the club, its description and rule.
    private func summary(_ club: Club) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("You are \(viewModel.myRole == .owner ? "the owner" : "\(viewModel.myRole == .admin ? "an" : "a") \(viewModel.myRole.label.lowercased())")")
                .textStyle(Typography.overline)
                .foregroundStyle(Tokens.Accent.brand)
            Text(club.name)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
            Text(club.description ?? "Your rowing community")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
            HStack(spacing: 6) {
                tag(club.joinPolicy.tag)
                tag(club.focus.rawValue)
                if let location = club.location, !location.isEmpty { tag(location) }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.card + 3)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .padding(.top, 6)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.statLabel)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Tokens.Surface.raised))
            .lineLimit(1)
    }

    // MARK: - Requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Join requests · \(viewModel.requests.count)")
            listCard(viewModel.requests, empty: "No pending requests.") { person in
                personLabel(person, detail: person.category.rawValue.capitalized)
                Button("Decline") { Task { await viewModel.respond(to: person, accept: false) } }
                    .buttonStyle(.rpText)
                Button("Accept") { Task { await viewModel.respond(to: person, accept: true) } }
                    .buttonStyle(.rpPill(isOn: true))
            }
        }
    }

    // MARK: - Invites

    private func inviteSection(_ club: Club) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Invite")
            NavigationLink {
                InviteRowerView(
                    clubName: club.name,
                    memberIds: Set(viewModel.members.map(\.id)),
                    invitedIds: Set(viewModel.invitations.map(\.id))
                )
            } label: {
                Text("Invite a rower")
            }
            .buttonStyle(.rpGlass)

            if let code = viewModel.inviteCode {
                HStack(spacing: Tokens.Spacing.gap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite code")
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                        Text(code)
                            .textStyle(Typography.metricValue)
                            .monospaced()
                            .foregroundStyle(Tokens.Accent.brand)
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                    Button("New") { isConfirmingNewCode = true }
                        .buttonStyle(.rpText)
                    ShareLink(item: "Join \(club.name) on Rowing Pals: go to Your crew › Find a club to join › Have an invite code?, and enter \(code).") {
                        Text("Share")
                    }
                    .buttonStyle(.rpPill(isOn: true))
                }
                .padding(Tokens.Spacing.card)
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                .padding(.top, Tokens.Spacing.loose)
            }

            if !viewModel.invitations.isEmpty {
                SectionTitle("Invited · \(viewModel.invitations.count)")
                listCard(viewModel.invitations, empty: "") { person in
                    personLabel(person, detail: "Hasn't answered yet")
                    Button("Withdraw") { Task { await viewModel.withdrawInvitation(to: person) } }
                        .buttonStyle(.rpText)
                }
            }
        }
    }

    // MARK: - Members

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Members · \(viewModel.members.count)")
            listCard(viewModel.members, empty: "No members yet.") { person in
                personLabel(person, detail: person.role.label)
                if person.id == viewModel.myId {
                    Text("You")
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Tokens.Surface.raised))
                } else if viewModel.myRole.canRemove(person.role) || !viewModel.myRole.assignableRoles(for: person.role).isEmpty {
                    Button("Manage") { managedPerson = person }
                        .buttonStyle(.rpText)
                }
            }
        }
    }

    // MARK: - Ownership

    @ViewBuilder
    private func ownershipSection(_ club: Club) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            SectionTitle(viewModel.myRole == .owner ? "Ownership" : "Membership")
            if viewModel.myRole == .owner {
                Button("Hand over ownership") { isChoosingNewOwner = true }
                    .buttonStyle(.rpGlass)
                    .disabled(viewModel.otherMembers.isEmpty)
                Button("Delete club") { isConfirmingDelete = true }
                    .buttonStyle(.rpDestructive)
                Text(viewModel.otherMembers.isEmpty
                     ? "You're the only member. Delete the club to leave it."
                     : "To leave, hand the club over to another member or delete it.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            } else {
                Button("Leave club") { isConfirmingLeave = true }
                    .buttonStyle(.rpDestructive)
            }
        }
    }

    // MARK: - Building blocks

    private func personLabel(_ person: ClubService.Person, detail: String) -> some View {
        HStack(spacing: Tokens.Spacing.gap) {
            AvatarPlaceholder(diameter: 38, name: person.displayName)
            VStack(alignment: .leading, spacing: 1) {
                Text(person.displayName)
                    .textStyle(Typography.name)
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                Text(detail)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer(minLength: 0)
        }
        .asButton { navigate(.profile(person.id)) }
    }

    /// One card of rows split by 1 pt lines, or a short line when there's nobody.
    @ViewBuilder
    private func listCard<Row: View>(
        _ people: [ClubService.Person], empty: String, @ViewBuilder row: @escaping (ClubService.Person) -> Row
    ) -> some View {
        if people.isEmpty {
            if !empty.isEmpty {
                Text(empty)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Tokens.Spacing.card)
                    .background(Self.cardShape.fill(Tokens.Surface.card))
                    .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                    HStack(spacing: Tokens.Spacing.gap) { row(person) }
                        .padding(12)
                    if index < people.count - 1 {
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
