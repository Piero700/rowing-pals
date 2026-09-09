//
//  SignInViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

@Observable
final class SignInViewModel {
    var email = ""
    var password = ""
    var displayName = ""
    var isSigningUp = false
    var errorMessage: String?
    var isLoading = false

    /// Payload for the one-time profiles insert. Not the full `Profile`
    /// model — the DB fills in every other column's default.
    private struct NewProfile: Encodable {
        let id: UUID
        let displayName: String

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if isSigningUp {
                try await signUp()
            } else {
                try await SupabaseService.shared.auth.signIn(email: email, password: password)
                try await ensureProfileExists()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signUp() async throws {
        // Stored in the auth user's own metadata so the display name survives
        // even when email confirmation delays the first real sign-in.
        let response = try await SupabaseService.shared.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(displayName)]
        )

        guard response.session != nil else {
            errorMessage = "Check your email to confirm your account, then sign in."
            isSigningUp = false
            return
        }

        try await ensureProfileExists()
    }

    /// Inserts the `profiles` row the first time this user has an
    /// authenticated session — whether that's immediately after sign-up (no
    /// email confirmation required) or on the sign-in that follows
    /// confirming it.
    private func ensureProfileExists() async throws {
        let session = try await SupabaseService.shared.auth.session
        let userId = session.user.id

        let existing: [Profile] = try await SupabaseService.shared
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        guard existing.isEmpty else { return }

        guard case let .string(name)? = session.user.userMetadata["display_name"] else {
            return
        }

        try await SupabaseService.shared
            .from("profiles")
            .insert(NewProfile(id: userId, displayName: name))
            .execute()
    }
}
