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
    /// The club being edited, so keeping its own name isn't "taken".
    @State private var editingClubId: UUID?
    /// Another club already has the typed name (decision 98), checked once typing pauses.
    @State private var isNameTaken = false

    private var canSave: Bool {
        ClubNameRules.problem(with: name) == nil && !isNameTaken && !isSaving
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
                        .guidance()
                }

                GroupedSection(hint: policyNote) {
                    GroupedRow(label: "Club name") {
                        TextField("Your club name", text: $name)
                            .textStyle(Typography.detail)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .onChange(of: name) { name = String(name.prefix(ClubNameRules.maxLength)) }
                            .task(id: name) { await checkName() }
                    }
                    GroupedDivider()
                    GroupedRow(label: "Location") {
                        TextField("City or online", text: $location)
                            .textStyle(Typography.detail)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .onChange(of: location) { location = String(location.prefix(80)) }
                    }
                    GroupedDivider()
                    GroupedRow(label: "Who can join") {
                        Menu {
                            ForEach(ClubJoinPolicy.allCases, id: \.self) { option in
                                Button(option.choiceLabel) { policy = option }
                            }
                        } label: {
                            GroupedValue(text: policy.choiceLabel)
                        }
                    }
                    GroupedDivider()
                    GroupedRow(label: "Club focus") {
                        Menu {
                            ForEach(ClubFocus.allCases, id: \.self) { option in
                                Button(option.rawValue) { focus = option }
                            }
                        } label: {
                            GroupedValue(text: focus.rawValue)
                        }
                    }
                    GroupedDivider()
                    TextField("Description: what brings your crew together?", text: $description, axis: .vertical)
                        .textStyle(Typography.detail)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1...6)
                        .onChange(of: description) { description = String(description.prefix(400)) }
                        .padding(.horizontal, Tokens.Grouped.rowPadding)
                        .padding(.vertical, Tokens.Spacing.loose)
                        .frame(maxWidth: .infinity, minHeight: Tokens.Grouped.rowHeight, alignment: .leading)
                }
                if isNameTaken {
                    GroupedError(text: ClubNameRules.takenMessage(for: name))
                        .padding(.top, Tokens.Spacing.tight)
                }

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
            ScreenHeader(title: mode == .create ? "Create a club" : "Edit club", onBack: { dismiss() }) {
                HeaderSaveButton(title: mode == .create ? "Create" : "Save", isSaving: isSaving, isDisabled: !canSave) {
                    Task { await save() }
                }
            }
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

    /// Create: your current club's name, for the "switch your membership" line. Edit: the
    /// club's current details.
    private func loadCurrent() async {
        guard let membership = try? await ClubService.membership(), let club = membership.club else { return }
        currentClubName = club.name
        guard mode == .edit else { return }
        editingClubId = club.id
        name = club.name
        description = club.description ?? ""
        location = club.location ?? ""
        policy = club.joinPolicy
        focus = club.focus
    }

    /// Asks the database whether the name is free once typing pauses. Before the clubs migration
    /// has run the check can't be made, so it says nothing and Create still answers.
    private func checkName() async {
        let typed = name
        guard ClubNameRules.problem(with: typed) == nil else {
            isNameTaken = false
            return
        }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        let isFree = (try? await ClubService.nameIsFree(ClubNameRules.tidied(typed), except: editingClubId)) ?? true
        guard !Task.isCancelled, typed == name else { return }
        isNameTaken = !isFree
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let details = ClubService.Details(
            p_name: ClubNameRules.tidied(name),
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
