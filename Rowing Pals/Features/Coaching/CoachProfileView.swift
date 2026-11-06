//
//  CoachProfileView.swift
//  Rowing Pals
//

import SwiftUI

/// The coach's own page, opened from their picture top right of every coach tab (CoachProfile;
/// decision 67): who they are and their club, **Switch to rowing** for someone who also rows, the
/// club's pages and attendance totals, and Settings, Edit profile and Log out.
struct CoachProfileView: View {
    @State private var me: ViewerContext.Snapshot?
    @State private var isSigningOut = false
    @AppStorage(AppMode.storageKey) private var appMode: AppMode = .rowing
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                identity
                if me?.isRower == true {
                    switchCard
                }
                group("Club") {
                    if let me {
                        row(me.clubName ?? "Your club",
                            subtitle: me.clubRole.canManageMembers ? "Members, requests and roles" : "Your crew",
                            isVerifiedClub: me.clubName != nil && me.clubIsVerified) {
                            navigate(me.clubRole.canManageMembers ? .manageClub : .clubHub)
                        }
                        divider
                    }
                    row("Squads", subtitle: "Who’s in each squad") { navigate(.squads) }
                    divider
                    row("Attendance totals") { navigate(.attendanceTotals) }
                }
                group("Account") {
                    row("Settings", subtitle: "Notifications, appearance, privacy") { navigate(.settings) }
                    divider
                    row("Edit profile", subtitle: "Name, photo and account type") { navigate(.editProfile) }
                    divider
                    row("Log out", titleColor: Tokens.Accent.brand, showsChevron: false) {
                        Task { await signOut() }
                    }
                    .disabled(isSigningOut)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Profile") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { me = try? await ViewerContext.shared.current() }
    }

    private var identity: some View {
        VStack(spacing: 0) {
            AvatarPlaceholder(diameter: Tokens.Size.editProfileAvatar, name: me?.displayName, userId: me?.userId)
            Text(me?.displayName ?? " ")
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.top, Tokens.Spacing.loose)
            HStack(spacing: Tokens.Spacing.verifiedGap) {
                if let clubName = me?.clubName {
                    Text("Coach ·")
                    ClubNameLabel(name: clubName, isVerified: me?.clubIsVerified ?? false, badgeSize: Tokens.Icon.badge)
                } else {
                    Text("Coach")
                }
            }
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Spacing.tight)
    }

    /// Someone who rows and coaches goes back to the rower version from here; Settings there has
    /// Switch to coaching. The same row in both places (user, 2026-10-18).
    private var switchCard: some View {
        SwitchVersionRow(toCoaching: false) {
            appMode = .rowing
            dismiss()
        }
        .padding(.top, Tokens.Spacing.group)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.group)
                .padding(.bottom, Tokens.Spacing.tight)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .clipShape(Self.cardShape)
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        }
    }

    private var divider: some View {
        Rectangle().fill(Tokens.Surface.line).frame(height: 1)
    }

    /// As Settings' rows: title 15 semibold, optional 13 description; 66 pt with one, 56 without.
    private func row(_ title: String, subtitle: String? = nil, titleColor: Color = Tokens.Ink.primary,
                     isVerifiedClub: Bool = false,
                     showsChevron: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 2) {
                    ClubNameLabel(name: title, isVerified: isVerifiedClub)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(titleColor)
                    if let subtitle {
                        Text(subtitle)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if showsChevron {
                    RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                        .textStyle(Typography.pill)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .frame(minHeight: subtitle == nil ? Tokens.Size.rowCompact : Tokens.Size.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
    }

    /// As Settings' Log out: this phone stops getting the coach's alerts, then signs out.
    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        await AccountService.signOut()
    }
}
