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
    @State private var isShowingPrivacyPolicy = false
    /// Whether iOS allows alerts, re-read on return from the iOS Settings app.
    @State private var push = PushNotificationService.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
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
    /// Appearance, Units and display, Notifications, Privacy, Account — then Delete account and
    /// the version. Left out by decision: the app-icon section (14) and CSV export (15). No
    /// "Who can comment" row: anyone who can see a post can comment on it (decision 33).
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
                        divider
                        row(title: "Match iPhone", subtitle: "Switches with your iPhone’s Light or Dark setting.") {
                            checkmark(appearance == .system)
                        } action: { appearance = .system }
                    }

                    group("Units and display") {
                        stackedRow(title: "Leaderboard distance", subtitle: "Volume rankings only; everything else is metres.") {
                            PillSegmentedControl(options: ["Metres", "km"], selection: Binding(
                                get: { distanceUnit == .kilometres ? 1 : 0 },
                                set: { distanceUnit = $0 == 1 ? .kilometres : .metres }
                            ), compact: true)
                        }
                        divider
                        stackedRow(title: "Pace shown as", subtitle: paceExample) {
                            PillSegmentedControl(options: ["Split", "Watts"], selection: Binding(
                                get: { paceDisplay == .watts ? 1 : 0 },
                                set: { paceDisplay = $0 == 1 ? .watts : .split }
                            ), compact: true)
                        }
                    }

                    notificationsGroup

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
                        row(title: "Log out", subtitle: nil, titleColor: Tokens.Accent.brand) { EmptyView() } action: {
                            Task { await viewModel.signOut() }
                        }
                    }

                    group("Help") {
                        if let supportMailtoURL = Self.supportMailtoURL {
                            Link(destination: supportMailtoURL) {
                                rowContent(title: "Contact us", subtitle: nil) { chevron }
                            }
                            divider
                        }
                        row(title: "Terms of Service", subtitle: nil) { chevron } action: { isShowingTerms = true }
                        divider
                        row(title: "Privacy Policy", subtitle: nil) { chevron } action: { isShowingPrivacyPolicy = true }
                    }

                    // v4: a card of its own with centred red text, 24 pt below Help.
                    Button { isShowingDeleteConfirmation = true } label: {
                        Text("Delete account")
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.System.error)
                            .frame(maxWidth: .infinity, minHeight: Tokens.Size.rowCompact)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                    .background(Self.cardShape.fill(Tokens.Surface.card))
                    .clipShape(Self.cardShape)
                    .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                    .padding(.top, Tokens.Spacing.group)
                    if let deleteError = viewModel.deleteError {
                        Text(deleteError)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.System.error)
                            .padding(.top, Tokens.Spacing.tight)
                            .padding(.horizontal, 4)
                    }
                    Text("Deleting your account removes every session, photo and comment permanently.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, Tokens.Spacing.tight)
                        .padding(.horizontal, 4)

                    Text(versionText)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Tokens.Spacing.group)
                }
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Settings") { dismiss() } }
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
            .sheet(isPresented: $isShowingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await push.refreshAuthorizationStatus() }
                }
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

    // MARK: - v3 building blocks

    /// Section title then one card (radius 30, card fill, card edge) of rows.
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
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        }
    }

    private var divider: some View {
        Rectangle().fill(Tokens.Surface.line).frame(height: 1)
    }

    /// v4 row: title 15 semibold, optional 13 description, trailing control; 66 pt tall with a
    /// description, 56 without.
    private func rowContent<Trailing: View>(
        title: String, subtitle: String?, titleColor: Color = Tokens.Ink.primary, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(titleColor)
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
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .frame(minHeight: subtitle == nil ? Tokens.Size.rowCompact : Tokens.Size.row)
        .contentShape(Rectangle())
    }

    /// v4 units row: title and description on top, the full-width control beneath.
    private func stackedRow<Control: View>(title: String, subtitle: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(subtitle)
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            control()
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.top, Tokens.Spacing.gap)
        .padding(.bottom, Tokens.Spacing.loose)
    }

    /// A row that is itself a control (a whole-row button) when `action` is given.
    @ViewBuilder
    private func row<Trailing: View>(
        title: String, subtitle: String?, titleColor: Color = Tokens.Ink.primary,
        @ViewBuilder trailing: () -> Trailing, action: (() -> Void)? = nil
    ) -> some View {
        if let action {
            Button(action: action) { rowContent(title: title, subtitle: subtitle, titleColor: titleColor, trailing: trailing) }
                .buttonStyle(IconPressStyle())
        } else {
            rowContent(title: title, subtitle: subtitle, titleColor: titleColor, trailing: trailing)
        }
    }

    private func checkmark(_ isOn: Bool) -> some View {
        Image(systemName: "checkmark")
            .textStyle(Typography.rowTitle)
            .foregroundStyle(Tokens.Accent.brand)
            .opacity(isOn ? 1 : 0)
            .accessibilityHidden(!isOn)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .textStyle(Typography.pill)
            .foregroundStyle(Tokens.Ink.secondary)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.detail)
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

    // MARK: - Notifications

    /// v3 §07: three switches (docs/design/v2-decisions.md #19; Quiet hours removed by #36). If iOS has
    /// alerts turned off for the app, a first row says so and opens the page in the iOS
    /// Settings app where they're turned back on — the switches alone can't override iOS.
    private var notificationsGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            group("Notifications") {
                if push.authorizationStatus == .denied {
                    row(title: "Notifications are off", subtitle: "Allow them in iOS Settings to get alerts.") {
                        chevron
                    } action: {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    divider
                }
                if viewModel.notificationSettings != nil {
                    toggleRow(title: "Comments and replies", subtitle: "Including your own threads", \.comments)
                    divider
                    toggleRow(title: "Personal bests", subtitle: "When you or a friend beats one", \.personalBests)
                    divider
                    toggleRow(
                        title: "Club activity",
                        subtitle: "New posts from \(viewModel.clubName ?? "your club")",
                        \.clubActivity
                    )
                } else {
                    rowContent(title: "Notifications", subtitle: "Loading…") { ProgressView() }
                }
            }
            if let error = viewModel.notificationError {
                Text(error)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.System.error)
                    .padding(.top, 6)
            }
        }
    }

    /// A 66 pt row whose trailing control is a switch; on = the success colour, as v3's
    /// `.switch` and the Review screen's "Include on leaderboards".
    private func toggleRow(
        title: String, subtitle: String, _ keyPath: WritableKeyPath<NotificationSettings, Bool>
    ) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.notificationSettings?[keyPath: keyPath] ?? false },
            set: { value in Task { await viewModel.updateNotifications { $0[keyPath: keyPath] = value } } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(subtitle)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        // v4: switches are brand blue when on.
        .tint(Tokens.Accent.brand)
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .frame(minHeight: Tokens.Size.row)
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
