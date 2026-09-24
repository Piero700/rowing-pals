//
//  SettingsView.swift
//  Rowing Pals
//

import SwiftUI

/// Task 17 built Contact (support email) and Terms of Service. Task 18
/// adds edit-profile, the novice/senior toggle, weekly target, sign out
/// and Delete Account.
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingTerms = false
    @State private var isShowingPrivacy = false
    @State private var isShowingDeleteConfirmation = false
    @FocusState private var isNameFocused: Bool
    /// Redesign phase B — per-device display preferences, not synced to
    /// the profile. See DesignSystem/DistanceUnit.swift (leaderboards only)
    /// and PaceDisplay.swift.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    private static let supportEmail = "support@rowingpals.app"
    private static let supportMailtoURL = URL(string: "mailto:\(supportEmail)")

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Display name", text: $viewModel.displayName)
                        .focused($isNameFocused)

                    Picker("Gender", selection: $viewModel.gender) {
                        Text("Male").tag(RowerGender.male)
                        Text("Female").tag(RowerGender.female)
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)

                    Picker("Category", selection: $viewModel.category) {
                        Text("Novice").tag(RowerCategory.novice)
                        Text("Senior").tag(RowerCategory.senior)
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $viewModel.weeklyTargetM, in: 0...50_000, step: 1_000) {
                        HStack {
                            Text("Weekly target")
                            Spacer()
                            Text(viewModel.weeklyTargetM.formattedMetres)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                    }

                    if let saveError = viewModel.saveError {
                        Text(saveError)
                            .foregroundStyle(Tokens.System.error)
                    }

                    Button {
                        isNameFocused = false
                        Task { await viewModel.save() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text("Save changes").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Novice means you're in your first season. You can change this any time.")
                }

                Section {
                    Picker("Leaderboard distance", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    Picker("Pace shown as", selection: $paceDisplay) {
                        ForEach(PaceDisplay.allCases, id: \.self) { display in
                            Text(display.label).tag(display)
                        }
                    }
                } header: {
                    Text("Units and display")
                } footer: {
                    Text("Leaderboard distance switches the Volume leaderboard between metres and kilometres. Everything else stays in metres. Pace applies everywhere a pace is shown.")
                }

                Section {
                    Button {
                        isShowingPrivacy = true
                    } label: {
                        HStack {
                            Label("Profile visibility", systemImage: "lock")
                            Spacer()
                            Text(viewModel.isPrivate ? "Private" : "Public")
                                .foregroundStyle(Tokens.Ink.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Tokens.Ink.faint)
                        }
                    }
                    .foregroundStyle(Tokens.Ink.primary)
                } header: {
                    Text("Privacy")
                }

                Section {
                    if let supportMailtoURL = Self.supportMailtoURL {
                        Link(destination: supportMailtoURL) {
                            Label(Self.supportEmail, systemImage: "envelope")
                        }
                    }
                } header: {
                    Text("Contact")
                } footer: {
                    Text("Reach us here to report something the in-app tools don't cover, or for anything else.")
                }

                Section {
                    Button {
                        isShowingTerms = true
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }

                Section {
                    Button("Sign out") {
                        Task { await viewModel.signOut() }
                    }
                    .foregroundStyle(Tokens.System.error)

                    Button("Delete Account", role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }
                    if let deleteError = viewModel.deleteError {
                        Text(deleteError)
                            .foregroundStyle(Tokens.System.error)
                    }
                } footer: {
                    Text("Deleting your account removes every session, photo and comment permanently. This can't be undone.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .sheet(isPresented: $isShowingTerms) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $isShowingPrivacy) {
                privacySheet
                    .presentationDetents([.medium])
            }
            .disabled(viewModel.isDeletingAccount)
            .overlay {
                if viewModel.isDeletingAccount {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(.ultraThinMaterial)
                }
            }
            .alert(
                "Delete your account?",
                isPresented: $isShowingDeleteConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
            } message: {
                Text("This permanently deletes your account and everything you've posted. This can't be undone.")
            }
        }
    }

    /// The prototype's privacy sheet (docs/design/
    /// rowing-pals-redesign-handoff-v2.md §2 Screen 07): one switch, with
    /// copy that says exactly what each state means.
    private var privacySheet: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Private account", isOn: Binding(
                        get: { viewModel.isPrivate },
                        set: { newValue in Task { await viewModel.setPrivate(newValue) } }
                    ))
                    .disabled(viewModel.isSavingPrivacy)
                } footer: {
                    if viewModel.isPrivate {
                        Text("Only people you approve can see your sessions, stats, personal bests, followers and following. Anyone can still send a request. People who already follow you keep following. Your sessions won't appear on leaderboards for anyone who doesn't follow you, and being in the same club doesn't give anyone access.")
                    } else {
                        Text("Anyone can see your sessions and stats, and follow you without asking. Switching to private later means new followers need your approval.")
                    }
                }
                if let error = viewModel.saveError {
                    Section {
                        Text(error).foregroundStyle(Tokens.System.error)
                    }
                }
            }
            .navigationTitle("Profile visibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingPrivacy = false }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
