//
//  SignInViewModel.swift
//  Rowing Pals
//

import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

/// Signing in and up (decision 66, user 2026-10-15): email and password, with the email
/// confirmed by a 6-digit code before the account is used; "Forgot password?" by a code too;
/// and Sign in with Apple or Google, so nobody has to remember a password. Codes are typed into
/// the app rather than links tapped, so nothing depends on an email link opening the app.
@Observable
final class SignInViewModel {
    enum Step: Equatable {
        case signIn
        case signUp
        /// Sign-up sent a code to confirm the email.
        case verifyEmail
        /// "Forgot password?": first the email, then the code and the new password.
        case forgotEmail
        case forgotCode
    }

    var step: Step = .signIn
    var email = ""
    var password = ""
    var displayName = ""
    var code = ""
    var newPassword = ""
    var errorMessage: String?
    /// A note that isn't an error ("We've sent a new code").
    var noticeMessage: String?
    var isLoading = false
    /// Gates the Sign up button — the zero-tolerance clause, task 17.
    var hasAgreedToTerms = false

    /// Supabase's emailed codes are 6 digits by default; up to 10 if the project's set longer.
    static let codeLengths = 6...10
    /// What Supabase asks of a password by default.
    static let minimumPasswordLength = 6
    /// Where Google sends the browser back to; listed in Supabase's Redirect URLs.
    static let oauthRedirect = URL(string: "rowingpals://auth-callback")

    /// The nonce for the Sign in with Apple request in flight, kept unhashed for Supabase.
    private var appleNonce: String?

    var isSigningUp: Bool { step == .signUp }

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

    func go(to step: Step) {
        self.step = step
        errorMessage = nil
        noticeMessage = nil
        if step == .forgotEmail || step == .verifyEmail { code = "" }
    }

    // MARK: - Email and password

    @MainActor
    func submit() async {
        errorMessage = nil
        noticeMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if isSigningUp {
                try await signUp()
            } else {
                try await SupabaseService.shared.auth.signIn(email: trimmedEmail, password: password)
                try await ensureProfileExists()
            }
        } catch let error as AuthError where error.errorCode == .emailNotConfirmed {
            // Signed up but never entered the code: send a fresh one and ask for it.
            try? await SupabaseService.shared.auth.resend(email: trimmedEmail, type: .signup)
            step = .verifyEmail
            code = ""
            noticeMessage = "Confirm your email first: we've sent a new code to \(trimmedEmail)."
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @MainActor
    private func signUp() async throws {
        guard hasAgreedToTerms else {
            errorMessage = "Please agree to the Terms of Service to continue."
            return
        }
        // Both stored in the auth user's own metadata, so the name and the moment of agreement
        // survive until the email is confirmed and the profiles row (task 17) is written.
        let response = try await SupabaseService.shared.auth.signUp(
            email: trimmedEmail,
            password: password,
            data: [
                "display_name": .string(displayName.trimmingCharacters(in: .whitespacesAndNewlines)),
                "terms_accepted_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
        )

        guard response.session != nil else {
            // Email confirmation is on (decision 66): the account waits for the code.
            step = .verifyEmail
            code = ""
            return
        }
        try await ensureProfileExists()
    }

    /// The code from the confirmation email: confirms the address and signs in.
    @MainActor
    func verifyCode() async {
        errorMessage = nil
        noticeMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await SupabaseService.shared.auth.verifyOTP(email: trimmedEmail, token: cleanCode, type: .signup)
            try await ensureProfileExists()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    @MainActor
    func resendCode() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            if step == .forgotCode {
                try await SupabaseService.shared.auth.resetPasswordForEmail(trimmedEmail)
            } else {
                try await SupabaseService.shared.auth.resend(email: trimmedEmail, type: .signup)
            }
            noticeMessage = "We've sent a new code to \(trimmedEmail)."
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    var cleanCode: String { code.filter(\.isWholeNumber) }
    var isCodeComplete: Bool { Self.codeLengths.contains(cleanCode.count) }

    // MARK: - Forgot password

    @MainActor
    func sendResetCode() async {
        errorMessage = nil
        noticeMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await SupabaseService.shared.auth.resetPasswordForEmail(trimmedEmail)
            step = .forgotCode
            code = ""
            newPassword = ""
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// The code proves the email is theirs and signs them in; then the new password is set.
    @MainActor
    func resetPassword() async {
        errorMessage = nil
        noticeMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await SupabaseService.shared.auth.verifyOTP(email: trimmedEmail, token: cleanCode, type: .recovery)
            _ = try await SupabaseService.shared.auth.update(user: UserAttributes(password: newPassword))
            try await ensureProfileExists()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Sign in with Apple

    /// Sets up the Apple request: the name and email scopes, and a nonce Supabase checks.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    @MainActor
    func finishApple(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            // Closing Apple's sheet isn't an error worth showing.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = Self.message(for: error)
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce else {
                errorMessage = "Apple didn't send what we need to sign you in. Please try again."
                return
            }
            isLoading = true
            defer { isLoading = false }
            do {
                _ = try await SupabaseService.shared.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
                )
                // Apple gives the name only the first time; keep it for the profile.
                let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }.joined(separator: " ")
                if !name.isEmpty {
                    _ = try? await SupabaseService.shared.auth.update(user: UserAttributes(data: ["display_name": .string(name)]))
                }
                try await ensureProfileExists()
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    // MARK: - Google

    /// Google's sign-in page in a secure in-app browser sheet; it hands back to the app here.
    @MainActor
    func signInWithGoogle() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await SupabaseService.shared.auth.signInWithOAuth(provider: .google, redirectTo: Self.oauthRedirect)
            try await ensureProfileExists()
        } catch {
            // Closing the sheet isn't an error worth showing.
            if let webError = error as? ASWebAuthenticationSessionError, webError.code == .canceledLogin { return }
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - The profile

    /// Inserts the `profiles` row the first time this user has a session — after confirming
    /// their email, or the first time they continue with Apple or Google. The name is the one
    /// they typed, or Apple's or Google's, or the start of their email; they can change it in
    /// Settings. Continuing with Apple or Google is agreeing to the Terms (the line under the
    /// buttons says so).
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

        let metadata = session.user.userMetadata
        func text(_ key: String) -> String? {
            if case let .string(value)? = metadata[key], !value.trimmingCharacters(in: .whitespaces).isEmpty { return value }
            return nil
        }
        let emailName = session.user.email?.split(separator: "@").first.map(String.init)
        let name = text("display_name") ?? text("full_name") ?? text("name") ?? emailName ?? "Rower"

        let termsAcceptedAt: Date
        if let iso = text("terms_accepted_at"), let parsed = ISO8601DateFormatter().date(from: iso) {
            termsAcceptedAt = parsed
        } else {
            termsAcceptedAt = Date()
        }

        try await SupabaseService.shared
            .from("profiles")
            .insert(NewProfile(id: userId, displayName: String(name.prefix(40)), termsAcceptedAt: termsAcceptedAt))
            .execute()
    }

    // MARK: - Helpers

    /// Plain words for the errors people actually hit.
    static func message(for error: Error) -> String {
        if let auth = error as? AuthError {
            switch auth.errorCode {
            case .invalidCredentials: return "That email and password don't match."
            case .otpExpired: return "That code has expired or isn't right. Tap Resend code for a new one."
            case .userAlreadyExists, .emailExists: return "There's already an account with that email. Sign in instead, or use Forgot password."
            case .weakPassword: return "Choose a longer password: at least \(minimumPasswordLength) characters."
            case .overEmailSendRateLimit, .overRequestRateLimit: return "Too many emails just now. Wait a minute, then try again."
            default: break
            }
            if case .weakPassword = auth { return "Choose a longer password: at least \(minimumPasswordLength) characters." }
            return auth.message
        }
        return error.localizedDescription
    }

    private static func randomNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in characters[Int.random(in: 0..<characters.count, using: &generator)] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
