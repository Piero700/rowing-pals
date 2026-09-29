//
//  ClubMemberSheet.swift
//  Rowing Pals
//

import SwiftUI

/// The prototype's "Manage <name>" sheet (decision 25): their club role — only the roles you
/// may give them — and Remove from club with its own confirmation, when you rank above them.
struct ClubMemberSheet: View {
    let person: ClubService.Person
    let myRole: ClubRole
    let onSetRole: (ClubRole) -> Void
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingRemove = false

    var body: some View {
        NavigationStack {
            Form {
                let roles = myRole.assignableRoles(for: person.role)
                if !roles.isEmpty {
                    Section {
                        ForEach(roles, id: \.self) { role in
                            Button {
                                if role != person.role { onSetRole(role) }
                                dismiss()
                            } label: {
                                HStack {
                                    Text(role.label).foregroundStyle(Tokens.Ink.primary)
                                    Spacer()
                                    if role == person.role {
                                        Image(systemName: "checkmark").foregroundStyle(Tokens.Accent.brand)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Club role")
                    } footer: {
                        Text("Admins answer join requests, invite and remove members. Co-owners also change roles and edit the club.")
                    }
                }
                if myRole.canRemove(person.role) {
                    Section {
                        Button("Remove from club", role: .destructive) { isConfirmingRemove = true }
                    } footer: {
                        Text("Their sessions, metres and PBs stay theirs. They can ask to join again.")
                    }
                }
            }
            .navigationTitle(person.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Remove \(person.displayName)?", isPresented: $isConfirmingRemove) {
                Button("Remove", role: .destructive) {
                    onRemove()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
