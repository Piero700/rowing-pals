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
    /// Gates the Sign up button — the zero-tolerance clause, task 17.
    var hasAgreedToTerms = false

    /// Payload for the one-time profiles insert. Not the full `Profile`
    /// model — the DB fills in every other column's default.
    private struct NewProfile: Encodable {
        let id: UUID
        let displayName: String
        let termsAcceptedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case termsAcceptedAt = "terms_accepted_at"
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
        guard hasAgreedToTerms else {
            errorMessage = "Please agree to the Terms of Service to continue."
            return
        }
        // Both stored in the auth user's own metadata, not just displayName,
        // so the moment of agreement survives even when email confirmation
        // delays the first real sign-in and the profiles row that actually
        // records terms_accepted_at (task 17) isn't written until then.
        let response = try await SupabaseService.shared.auth.signUp(
            email: email,
            password: password,
            data: [
                "display_name": .string(displayName),
                "terms_accepted_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
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
        let termsAcceptedAt: Date
        if case let .string(iso)? = session.user.userMetadata["terms_accepted_at"],
           let parsed = ISO8601DateFormatter().date(from: iso) {
            termsAcceptedAt = parsed
        } else {
            // Shouldn't happen — signUp() always sets this before this
            // profile could exist — but a profile without it is a bigger
            // problem than defaulting to "now" for it.
            termsAcceptedAt = Date()
        }

        try await SupabaseService.shared
            .from("profiles")
            .insert(NewProfile(id: userId, displayName: name, termsAcceptedAt: termsAcceptedAt))
            .execute()
    }
}
