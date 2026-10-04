//
//  ClubFormView.swift
//  Rowing Pals
//

import SwiftUI

/// Create a club, or edit yours (co-owners and the owner) — the prototype's `create-club`
/// form (docs/design/rowing-pals-redesign-handoff-v2.md §12): name, description, location,
/// "Who can join?" and "Club focus". Creating makes you the owner and moves you out of your
/// current club; an owner must hand theirs over first, which the server enforces and says.
struct ClubFormView: View {
    enum Mode {
        case create
        case edit
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var location = ""
    @State private var policy: ClubJoinPolicy = .approval
    @State private var focus: ClubFocus = .allRowing
    @State private var currentClubName: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if mode == .create {
                    Text(intro)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 14)
                }

                field("Club name") {
                    TextField("Your club name", text: $name)
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { name = String(name.prefix(60)) }
                }
                field("Description") {
                    TextField("What brings your crew together?", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: description) { description = String(description.prefix(400)) }
                }
                field("Location") {
                    TextField("City or online", text: $location)
                        .textInputAutocapitalization(.words)
                        .onChange(of: location) { location = String(location.prefix(80)) }
                }
                field("Who can join?") {
                    choice(policy.choiceLabel) {
                        ForEach(ClubJoinPolicy.allCases, id: \.self) { option in
                            Button(option.choiceLabel) { policy = option }
                        }
                    }
                }
                field("Club focus") {
                    choice(focus.rawValue) {
                        ForEach(ClubFocus.allCases, id: \.self) { option in
                            Button(option.rawValue) { focus = option }
                        }
                    }
                }

                Text(policyNote)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)

                if let errorMessage {
                    Text(errorMessage)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: mode == .create ? "Create a club" : "Edit club") { dismiss() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(mode == .create ? "Create club" : "Save changes") { Task { await save() } }
                .buttonStyle(.rpPrimary)
                .disabled(!canSave)
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.top, Tokens.Spacing.loose)
                .padding(.bottom, Tokens.Spacing.screen)
                .background(Tokens.Base.ground)
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Tokens.Base.ground)
        .dismissesKeyboardOnTap()
        .task { await loadCurrent() }
    }

    private var intro: String {
        var text = "Start your crew. You'll become the club owner."
        if let currentClubName {
            text += " Creating this club will switch your membership from \(currentClubName)."
        }
        return text
    }

    private var policyNote: String {
        switch policy {
        case .open: "Anyone can join straight away. Owners can appoint admins or co-owners to help run the club."
        case .approval: "Rowers ask to join; admins, co-owners and the owner accept or decline."
        case .invite: "Only rowers you invite, or who have the club's code, can join."
        }
    }

    /// v3 field: 12.5 pt label over a 52 pt input (card fill, 1 pt line, radius 24).
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .textStyle(Typography.fieldLabel)
                .foregroundStyle(Tokens.Ink.secondary)
            content()
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.input, alignment: .leading)
                .background(shape.fill(Tokens.Surface.card))
                .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
        }
        .padding(.bottom, Tokens.Spacing.loose)
    }

    /// A select: the current choice with a chevron; tapping lists the options.
    private func choice<Options: View>(_ current: String, @ViewBuilder options: () -> Options) -> some View {
        Menu {
            options()
        } label: {
            HStack {
                Text(current)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    /// Create: your current club's name, for the "switch your membership" line. Edit: the
    /// club's current details.
    private func loadCurrent() async {
        guard let membership = try? await ClubService.membership(), let club = membership.club else { return }
        currentClubName = club.name
        guard mode == .edit else { return }
        name = club.name
        description = club.description ?? ""
        location = club.location ?? ""
        policy = club.joinPolicy
        focus = club.focus
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let details = ClubService.Details(
            p_name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            p_description: description,
            p_location: location,
            p_policy: policy,
            p_focus: focus
        )
        do {
            if mode == .create {
                try await ClubService.create(details)
            } else {
                try await ClubService.update(details)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
