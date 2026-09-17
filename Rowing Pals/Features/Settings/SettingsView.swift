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
    @State private var isShowingDeleteConfirmation = false
    @FocusState private var isNameFocused: Bool

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
                            Text("\(viewModel.weeklyTargetM.formattedWithGrouping)m")
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                    }

                    if let saveError = viewModel.saveError {
                        Text(saveError)
                            .foregroundStyle(Tokens.Accent.live)
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
                    .foregroundStyle(Tokens.Accent.live)

                    Button("Delete Account", role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }
                    if let deleteError = viewModel.deleteError {
                        Text(deleteError)
                            .foregroundStyle(Tokens.Accent.live)
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
}

#Preview {
    SettingsView()
}
