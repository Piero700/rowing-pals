//
//  Rowing_PalsApp.swift
//  Rowing Pals
//
//  Created by Piero on 08/09/2026.
//

import SwiftUI

@main
struct Rowing_PalsApp: App {
    @State private var authState = AuthState()

    var body: some Scene {
        WindowGroup {
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
        .environment(authState)
    }
}
