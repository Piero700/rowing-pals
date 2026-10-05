//
//  Rowing_PalsApp.swift
//  Rowing Pals
//
//  Created by Piero on 08/09/2026.
//

import SwiftUI

@main
struct Rowing_PalsApp: App {
    /// Push notifications' device-token and alert-tap callbacks (see `AppDelegate`).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authState = AuthState()

    /// Settings → Appearance; dark is the primary design.
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark

    var body: some Scene {
        WindowGroup {
            Group {
            if !authState.isSignedIn {
                SignInView()
            } else if authState.needsOnboarding == nil {
                // Briefly true right after sign-in while the profile's
                // club_id is being checked — avoids a flash of RootView.
                ProgressView()
            } else if authState.needsOnboarding == true {
                ClubSearchView()
            } else {
                RootView()
            }
            }
            .onChange(of: appearance, initial: true) { appearance.apply() }
        }
        .environment(authState)
    }
}
