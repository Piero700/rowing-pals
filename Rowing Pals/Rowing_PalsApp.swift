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
    /// Helper text (decision 98): the local days the app has been opened on, and the person's own
    /// choice from Settings → Help, which wins once made.
    @AppStorage(GuidanceStore.daysKey) private var guidanceDays = ""
    @AppStorage(GuidanceStore.choiceKey) private var guidanceChoice = ""
    @Environment(\.scenePhase) private var scenePhase

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
                // Onboarding, with Create a club (decision 98).
                OnboardingHost()
            } else {
                // The rower version or the coach version (decision 67).
                AppShell()
            }
            }
            .onChange(of: appearance, initial: true) { appearance.apply() }
            .environment(\.showsGuidance, GuidanceRules.showsGuidance(
                storedDays: guidanceDays, choice: GuidanceRules.Choice(rawValue: guidanceChoice) ?? .automatic
            ))
            // Each time the app comes to the front counts today, once per local day.
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active else { return }
                guidanceDays = GuidanceRules.recording(GuidanceRules.dayKey(for: .now), in: guidanceDays)
            }
        }
        .environment(authState)
    }
}
