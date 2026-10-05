//
//  InviteRowerView.swift
//  Rowing Pals
//

import SwiftUI

/// "Invite a rower" (decision 25): search rowers and invite them to your club. They see the
/// invitation under Your crew and accept or decline. People already in the club aren't listed.
struct InviteRowerView: View {
    let clubName: String
    let memberIds: Set<UUID>
    @State var invitedIds: Set<UUID>

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var people: [PersonSummary] = []
    @State private var busyIds: Set<UUID> = []
    @State private var errorMessage: String?

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("They'll see the invitation under Your crew and can join \(clubName) straight away.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 12)
                searchField
                    .padding(.bottom, 14)
                if let errorMessage {
                    Text(errorMessage)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.bottom, 12)
                }
                let candidates = people.filter { !memberIds.contains($0.id) }
                if candidates.isEmpty {
                    Text(query.isEmpty ? "Search for a rower by name." : "No rowers match that name.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, person in
                            row(person)
                            if index < candidates.count - 1 {
                                Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                            }
                        }
                    }
                    .background(Self.cardShape.fill(Tokens.Surface.card))
                    .clipShape(Self.cardShape)
                    .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Invite a rower") { dismiss() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Tokens.Base.ground)
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            people = (try? await FollowService.search(query)) ?? []
        }
    }

    private var searchField: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 20, height: 20)
                .foregroundStyle(Tokens.Ink.secondary)
                .accessibilityHidden(true)
            TextField("Search rowers", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Tokens.Size.input)
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
    }

    private func row(_ person: PersonSummary) -> some View {
        let isInvited = invitedIds.contains(person.id)
        return HStack(spacing: Tokens.Spacing.gap) {
            AvatarPlaceholder(diameter: 38, name: person.displayName, userId: person.id)
            VStack(alignment: .leading, spacing: 1) {
                Text(person.displayName)
                    .textStyle(Typography.name)
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                Text(person.club?.name ?? "No club")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(isInvited ? "Invited" : "Invite") {
                guard !isInvited else { return }
                Task { await invite(person) }
            }
            .buttonStyle(.rpPill(isOn: isInvited))
            .disabled(busyIds.contains(person.id))
        }
        .padding(12)
    }

    private func invite(_ person: PersonSummary) async {
        busyIds.insert(person.id)
        defer { busyIds.remove(person.id) }
        do {
            try await ClubService.invite(person.id)
            invitedIds.insert(person.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
