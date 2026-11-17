//
//  AppShell.swift
//  Rowing Pals
//

import SwiftUI

/// The signed-in app: the rower version or the coach version (decision 67). A coach who doesn't
/// row always gets the coach version; one who also rows gets the version they used last, and
/// switches from the coach's Profile or Settings. Everyone else gets the rower version. An account
/// without a username chooses one first (decision 85).
struct AppShell: View {
    @AppStorage(AppMode.storageKey) private var preferred: AppMode = .rowing
    /// Nil until the account is read, which is quick (the viewer context is shared and cached).
    @State private var account: Account?

    private struct Account: Equatable {
        let isCoach: Bool
        let isRower: Bool
        /// No username yet (decision 85): asked for before anything else.
        var needsUsername = false
        var displayName = ""
        /// No date of birth yet (decision 107): asked next, before the app opens.
        var needsBirthDate = false
    }

    var body: some View {
        Group {
            if let account, account.needsUsername {
                ChooseUsernameView(name: account.displayName) {
                    Task { await loadAccount() }
                }
            } else if let account, account.needsBirthDate {
                BirthDateView {
                    Task { await loadAccount() }
                }
            } else if let account {
                if AppMode.resolved(isCoach: account.isCoach, isRower: account.isRower, preferred: preferred) == .coaching {
                    CoachRootView()
                } else {
                    RootView()
                }
            } else {
                ProgressView()
                    .tint(Tokens.Ink.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Tokens.Base.ground)
            }
        }
        .task { await loadAccount() }
        // Made a coach or no longer one, or the account type changed in Edit profile.
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await loadAccount() }
        }
    }

    /// Offline, the rower version opens: it copes with no connection already. The date of birth is
    /// only asked for when the check itself worked, so a bad connection never locks anyone out.
    private func loadAccount() async {
        async let viewerRequest = try? await ViewerContext.shared.current()
        async let detailsRequest = try? await AthletePrivateService.mine()
        let (viewer, details) = await (viewerRequest, detailsRequest)
        if let viewer {
            account = Account(isCoach: viewer.isCoach, isRower: viewer.isRower,
                              needsUsername: viewer.needsUsername, displayName: viewer.displayName,
                              needsBirthDate: details.map { $0.birthDate == nil } ?? false)
        } else if account == nil {
            account = Account(isCoach: false, isRower: true)
        }
    }
}
