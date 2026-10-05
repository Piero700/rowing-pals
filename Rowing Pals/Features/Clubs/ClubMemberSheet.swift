//
//  ClubMemberSheet.swift
//  Rowing Pals
//

import SwiftUI

/// A member's sheet in Manage club, to the v4 CoachMakeCoach artboard (decisions 25, 39): who
/// they are and when they joined; their club role — only the roles you may give them; **Make
/// coach** for the owner and co-owners; and Remove from club when you rank above them. Role and
/// coach changes wait for Done; Cancel drops them.
struct ClubMemberSheet: View {
    let person: ClubService.Person
    let myRole: ClubRole
    /// True when this is the signed-in member's own sheet (an owner can coach).
    let isMe: Bool
    let onSave: (_ role: ClubRole?, _ isCoach: Bool?) -> Void
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingRemove = false
    @State private var role: ClubRole
    @State private var isCoach: Bool

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(
        person: ClubService.Person,
        myRole: ClubRole,
        isMe: Bool,
        onSave: @escaping (_ role: ClubRole?, _ isCoach: Bool?) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.person = person
        self.myRole = myRole
        self.isMe = isMe
        self.onSave = onSave
        self.onRemove = onRemove
        _role = State(initialValue: person.role)
        _isCoach = State(initialValue: person.isCoach)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    identity

                    let roles = isMe ? [] : myRole.assignableRoles(for: person.role)
                    if !roles.isEmpty {
                        sectionTitle("Club role")
                            .padding(.top, Tokens.Spacing.sectionTop)
                        PillSegmentedControl(
                            options: roles.map(\.label),
                            selection: Binding(
                                get: { roles.firstIndex(of: role) ?? 0 },
                                set: { role = roles[$0] }
                            )
                        )
                        footnote("Admins answer join requests and invite members. Co-owners also change roles and edit the club.")
                    }

                    if myRole.canMakeCoach {
                        sectionTitle("Coaching")
                            .padding(.top, Tokens.Spacing.group)
                        HStack(spacing: Tokens.Spacing.loose) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Make coach")
                                    .textStyle(Typography.rowTitle)
                                    .foregroundStyle(Tokens.Ink.primary)
                                Text("Sees every member’s training, sets workouts and takes attendance.")
                                    .textStyle(Typography.meta)
                                    .foregroundStyle(Tokens.Ink.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("Make coach", isOn: $isCoach)
                                .labelsHidden()
                                .tint(Tokens.Accent.brand)
                        }
                        .padding(.horizontal, Tokens.Spacing.card)
                        .padding(.vertical, Tokens.Spacing.loose)
                        .frame(minHeight: Tokens.Size.row)
                        .background(Self.cardShape.fill(Tokens.Surface.card))
                        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                        footnote("Coaching is separate from club roles: being a coach adds no member-management powers, and being an admin adds no coaching powers.")
                    }

                    if !isMe && myRole.canRemove(person.role) {
                        Button("Remove from club") { isConfirmingRemove = true }
                            .buttonStyle(.rpDestructive)
                            .padding(.top, Tokens.Spacing.group)
                    }
                }
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.bottom, Tokens.Spacing.group)
            }
            .scrollIndicators(.hidden)
        }
        .background(Tokens.Surface.card)
        .presentationBackground(Tokens.Surface.card)
        .presentationDragIndicator(.visible)
        .alert("Remove \(person.displayName)?", isPresented: $isConfirmingRemove) {
            Button("Remove", role: .destructive) {
                onRemove()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their sessions, metres and PBs stay theirs. They can ask to join again.")
        }
    }

    /// Cancel · Member · Done.
    private var header: some View {
        ZStack {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.rpText)
                Spacer()
                Button("Done") {
                    onSave(role != person.role ? role : nil, isCoach != person.isCoach ? isCoach : nil)
                    dismiss()
                }
                .buttonStyle(.rpText)
                .fontWeight(.semibold)
            }
            Text("Member")
                .textStyle(Typography.navTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Tokens.Spacing.tight)
        .padding(.top, Tokens.Spacing.loose)
        .frame(minHeight: Tokens.Size.minTap)
    }

    /// Picture, name, and "Senior · joined Sep 2025".
    private var identity: some View {
        HStack(spacing: Tokens.Spacing.loose) {
            AvatarPlaceholder(diameter: Tokens.Size.memberSheetAvatar, name: person.displayName, userId: person.id)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(detail)
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, Tokens.Spacing.loose)
    }

    private var detail: String {
        var parts = [person.isRower ? person.category.rawValue.capitalized : "Doesn’t row"]
        if let joined = person.clubJoinedAt {
            parts.append("joined \(joined.formatted(.dateTime.month(.abbreviated).year()))")
        }
        return parts.joined(separator: " · ")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, Tokens.Spacing.tight)
            .accessibilityAddTraits(.isHeader)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.tight)
            .fixedSize(horizontal: false, vertical: true)
    }
}
