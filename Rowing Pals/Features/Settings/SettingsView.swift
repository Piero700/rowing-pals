//
//  SettingsView.swift
//  Rowing Pals
//

import SwiftUI

/// Task 17 builds only what Guideline 1.2's Contact mechanism needs — the
/// support email link — plus a way back into the Terms of Service. Task 18
/// adds edit-profile, the novice/senior toggle, weekly target, sign out
/// and Delete Account to this same screen.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingTerms = false

    private static let supportEmail = "support@rowingpals.app"
    private static let supportMailtoURL = URL(string: "mailto:\(supportEmail)")

    var body: some View {
        NavigationStack {
            List {
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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingTerms) {
                TermsOfServiceView()
            }
        }
    }
}

#Preview {
    SettingsView()
}
