//
//  AuthState.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Whether the app should show sign-in, club onboarding, or the main tab
/// shell. Watches Supabase's auth state so a session found at launch (or one
/// that ends) updates the UI without any manual polling.
@Observable
final class AuthState {
    var isSignedIn = false
    /// nil while unknown (still loading, or signed out). Once signed in,
    /// true until the profile has a club_id, per task 06.
    var needsOnboarding: Bool?

    private var watchTask: Task<Void, Never>?

    init() {
        watchTask = Task {
            for await (_, session) in SupabaseService.shared.auth.authStateChanges {
                isSignedIn = session != nil
                if session != nil {
                    await refreshOnboardingStatus()
                } else {
                    needsOnboarding = nil
                }
            }
        }
    }

    /// Re-checks whether the signed-in user still needs onboarding. Called
    /// again by `ClubSearchView` once it writes a club_id, so the app
    /// transitions straight to `RootView` without a restart.
    func refreshOnboardingStatus() async {
        do {
            let userId = try await SupabaseService.shared.auth.session.user.id
            let profile: Profile = try await SupabaseService.shared
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            needsOnboarding = profile.clubId == nil
        } catch {
            needsOnboarding = nil
        }
    }

    deinit {
        watchTask?.cancel()
    }
}
