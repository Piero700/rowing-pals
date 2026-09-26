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
    /// Redesign phase B — per-device display preferences, not synced to
    /// the profile. See DesignSystem/DistanceUnit.swift (leaderboards only)
    /// and PaceDisplay.swift.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    private static let supportEmail = "support@rowingpals.app"
    private static let supportMailtoURL = URL(string: "mailto:\(supportEmail)")

    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    /// v3 Settings (`docs/design/v3/RP Screen.dc.html` §07): grouped cards of 66 pt rows —
    /// Appearance, Units and display, Privacy, Account — then Delete account and the version.
    /// Left out by decision: the app-icon section (14) and CSV export (15). Notifications, quiet
    /// hours and "Who can comment" wait until the app sends notifications / the user confirms them.
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    group("Appearance") {
                        row(title: "Dark mode", subtitle: "Reduce glare in low light.") {
                            checkmark(appearance == .dark)
                        } action: { appearance = .dark }
                        divider
                        row(title: "Light mode", subtitle: "Higher contrast in daylight.") {
                            checkmark(appearance == .light)
                        } action: { appearance = .light }
                    }

                    group("Units and display") {
                        row(title: "Leaderboard distance", subtitle: "Volume rankings only; everything else is metres.") {
                            PillSegmentedControl(options: ["Metres", "km"], selection: Binding(
                                get: { distanceUnit == .kilometres ? 1 : 0 },
                                set: { distanceUnit = $0 == 1 ? .kilometres : .metres }
                            ), compact: true)
                            .frame(width: 145)
                        }
                        divider
                        row(title: "Pace shown as", subtitle: paceExample) {
                            PillSegmentedControl(options: ["Split", "Watts"], selection: Binding(
                                get: { paceDisplay == .watts ? 1 : 0 },
                                set: { paceDisplay = $0 == 1 ? .watts : .split }
                            ), compact: true)
                            .frame(width: 145)
                        }
                    }

                    group("Privacy") {
                        row(title: "Profile visibility", subtitle: nil) {
                            value(viewModel.isPrivate ? "Private" : "Public")
                            chevron
                        } action: { isShowingPrivacy = true }
                    }

                    group("Account") {
                        NavigationLink {
                            EditProfileView(viewModel: viewModel)
                        } label: {
                            rowContent(title: "Edit profile", subtitle: "Name, gender, level and weekly target") { chevron }
                        }
                        .buttonStyle(IconPressStyle())
                        divider
                        row(title: "Log out", subtitle: nil) { EmptyView() } action: {
                            Task { await viewModel.signOut() }
                        }
                    }

                    group("Help") {
                        if let supportMailtoURL = Self.supportMailtoURL {
                            Link(destination: supportMailtoURL) {
                                rowContent(title: "Contact us", subtitle: Self.supportEmail) { chevron }
                            }
                            divider
                        }
                        row(title: "Terms of Service", subtitle: nil) { chevron } action: { isShowingTerms = true }
                    }

                    Button("Delete account") { isShowingDeleteConfirmation = true }
                        .buttonStyle(.rpDestructive)
                        .padding(.top, Tokens.Spacing.gap)
                    if let deleteError = viewModel.deleteError {
                        Text(deleteError)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.System.error)
                            .padding(.top, 6)
                    }
                    Text("Deleting your account removes every session, photo and comment permanently.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, 6)

                    Text(versionText)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Spacing.loose)
                }
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.bottom, 22)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .background(Tokens.Base.ground)
            .toolbar(.hidden, for: .navigationBar)
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
        // An open sheet doesn't pick up the root's scheme change until it's presented again,
        // so the choice is applied here too and shows the moment it's tapped.
        .preferredColorScheme(appearance.colorScheme)
    }

    // MARK: - v3 building blocks

    private var header: some View {
        HStack(spacing: Tokens.Spacing.gap) {
            GlassIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") { dismiss() }
            Text("Settings")
                .textStyle(Typography.navTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, 14)
        .frame(minHeight: 58)
        .background(Tokens.Base.ground)
    }

    /// Section title then one card (radius 30, card fill, card edge) of rows.
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 2)
                .padding(.top, Tokens.Spacing.sectionTop)
                .padding(.bottom, Tokens.Spacing.sectionBottom)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .clipShape(Self.cardShape)
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        }
    }

    private var divider: some View {
        Rectangle().fill(Tokens.Surface.line).frame(height: 1)
    }

    /// v3 row: title 14 bold, optional 12.8 subtitle, trailing control; at least 66 pt tall.
    private func rowContent<Trailing: View>(title: String, subtitle: String?, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: Tokens.Spacing.gap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .tabularNumerals()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, Tokens.Spacing.loose)
        .padding(.vertical, 9)
        .frame(minHeight: 66)
        .contentShape(Rectangle())
    }

    /// A row that is itself a control (a whole-row button) when `action` is given.
    @ViewBuilder
    private func row<Trailing: View>(
        title: String, subtitle: String?, @ViewBuilder trailing: () -> Trailing, action: (() -> Void)? = nil
    ) -> some View {
        if let action {
            Button(action: action) { rowContent(title: title, subtitle: subtitle, trailing: trailing) }
                .buttonStyle(IconPressStyle())
        } else {
            rowContent(title: title, subtitle: subtitle, trailing: trailing)
        }
    }

    private func checkmark(_ isOn: Bool) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Tokens.Accent.brand)
            .opacity(isOn ? 1 : 0)
            .accessibilityHidden(!isOn)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tokens.Ink.secondary)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Tokens.Ink.secondary)
    }

    private var paceExample: String {
        // 1:58.7 /500m, shown in the chosen form.
        let sample = 118_700
        return paceDisplay == .split ? "\(sample.formattedPace(display: .split)) /500m" : sample.formattedPace(display: .watts)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Rowing Pals \(version) (\(build))"
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
