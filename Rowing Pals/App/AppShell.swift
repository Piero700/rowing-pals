//
//  AppShell.swift
//  Rowing Pals
//

import SwiftUI

/// The signed-in app: the rower version or the coach version (decision 67). A coach who doesn't
/// row always gets the coach version; one who also rows gets the version they used last, and
/// switches from the coach's Profile or Settings. Everyone else gets the rower version.
struct AppShell: View {
    @AppStorage(AppMode.storageKey) private var preferred: AppMode = .rowing
    /// Nil until the account is read, which is quick (the viewer context is shared and cached).
    @State private var account: Account?

    private struct Account: Equatable {
        let isCoach: Bool
        let isRower: Bool
    }

    var body: some View {
        Group {
            if let account {
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

    /// Offline, the rower version opens: it copes with no connection already.
    private func loadAccount() async {
        if let viewer = try? await ViewerContext.shared.current() {
            account = Account(isCoach: viewer.isCoach, isRower: viewer.isRower)
        } else if account == nil {
            account = Account(isCoach: false, isRower: true)
        }
    }
}
