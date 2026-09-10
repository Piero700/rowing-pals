//
//  AuthState.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Whether the app should show sign-in or the main tab shell. Watches
/// Supabase's auth state so a session found at launch (or one that ends)
/// updates the UI without any manual polling.
@Observable
final class AuthState {
    var isSignedIn = false

    private var watchTask: Task<Void, Never>?

    init() {
        watchTask = Task {
            for await (_, session) in SupabaseService.shared.auth.authStateChanges {
                isSignedIn = session != nil
            }
        }
    }

    deinit {
        watchTask?.cancel()
    }
}
