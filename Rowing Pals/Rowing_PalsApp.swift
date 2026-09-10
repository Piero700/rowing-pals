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
            if authState.isSignedIn {
                RootView()
            } else {
                SignInView()
            }
        }
    }
}
