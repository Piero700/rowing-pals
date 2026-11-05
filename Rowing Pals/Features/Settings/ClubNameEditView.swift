//
//  ClubNameEditView.swift
//  Rowing Pals
//

import SwiftUI

/// Settings → Your club → Club name (decision 98): the owner renames the club. Names are unique
/// ignoring capitals and spaces, checked as it's typed and again by the database on Save.
struct ClubNameEditView: View {
    let currentName: String
    let clubId: UUID
    /// Called with the saved name, so Settings shows it straight away.
    let onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isNameTaken = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isUnchanged: Bool { ClubNameRules.tidied(name) == currentName }

    private var canSave: Bool {
        ClubNameRules.problem(with: name) == nil && !isNameTaken && !isUnchanged && !isSaving
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                Text("Club name")
                    .textStyle(Typography.fieldLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
                TextField("Your club name", text: $name)
                    .textInputAutocapitalization(.words)
                    .textStyle(Typography.body)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: Tokens.Size.input)
                    .background(RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous).fill(Tokens.Surface.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
                            .strokeBorder(Tokens.Surface.line, lineWidth: 1)
                    }
                    .onChange(of: name) { name = String(name.prefix(ClubNameRules.maxLength)) }
                    .task(id: name) { await checkName() }

                if isNameTaken {
                    Text(ClubNameRules.takenMessage(for: name))
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                }
                Text("Everyone sees the new name straight away: on the club, in search and beside every member.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .guidance()
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.loose)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Club name") { dismiss() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Save name") { Task { await save() } }
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
        .onAppear { if name.isEmpty { name = currentName } }
    }

    private func checkName() async {
        let typed = name
        guard ClubNameRules.problem(with: typed) == nil, !isUnchanged else {
            isNameTaken = false
            return
        }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        let isFree = (try? await ClubService.nameIsFree(ClubNameRules.tidied(typed), except: clubId)) ?? true
        guard !Task.isCancelled, typed == name else { return }
        isNameTaken = !isFree
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await ClubService.rename(to: name)
            onSaved(ClubNameRules.tidied(name))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
