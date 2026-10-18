//
//  UsernameService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Usernames (decision 85): whether one's free, setting yours, and signing in or resetting a
/// password with one. Signing in and resetting go through the `username-auth` Edge Function, which
/// looks the email up on the server — the app never learns anyone's email from a username.
enum UsernameService {
    /// A plain-words failure from `username-auth` ("That username and password don’t match.").
    struct Failure: LocalizedError {
        let code: String
        let message: String
        var errorDescription: String? { message }
    }

    /// Whether `username` is free (your own counts as free).
    static func isAvailable(_ username: String) async throws -> Bool {
        struct Params: Encodable { let p_username: String }
        return try await SupabaseService.shared
            .rpc("username_available", params: Params(p_username: UsernameRules.normalised(username)))
            .execute().value
    }

    /// Sets your username; returns it as stored. The database explains what's wrong in its error.
    @discardableResult
    static func set(_ username: String) async throws -> String {
        struct Params: Encodable { let p_username: String }
        let value: String = try await SupabaseService.shared
            .rpc("set_username", params: Params(p_username: UsernameRules.normalised(username)))
            .execute().value
        ViewerContext.shared.invalidate()
        return value
    }

    /// Signs in with a username and password.
    static func signIn(username: String, password: String) async throws {
        try await startSession(Body(action: "sign-in", username: UsernameRules.normalised(username), password: password))
    }

    /// Emails a reset code to the account with this username. Says nothing about whether it exists.
    static func sendReset(username: String) async throws {
        let _: Done = try await call(Body(action: "send-reset", username: UsernameRules.normalised(username)))
    }

    /// Checks the emailed code, sets the new password and signs in.
    static func reset(username: String, code: String, newPassword: String) async throws {
        try await startSession(Body(action: "reset", username: UsernameRules.normalised(username),
                                    code: code, newPassword: newPassword))
    }

    // MARK: - The function

    private struct Body: Encodable {
        let action: String
        let username: String
        var password: String?
        var code: String?
        var newPassword: String?
    }

    private struct SessionTokens: Decodable {
        let accessToken: String
        let refreshToken: String
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }

    private struct Done: Decodable { let ok: Bool }

    private struct ErrorBody: Decodable {
        let error: String
        let message: String
    }

    private static func startSession(_ body: Body) async throws {
        let tokens: SessionTokens = try await call(body)
        try await SupabaseService.shared.auth.setSession(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
    }

    private static func call<T: Decodable>(_ body: Body) async throws -> T {
        do {
            return try await SupabaseService.shared.functions.invoke("username-auth", options: FunctionInvokeOptions(body: body))
        } catch let FunctionsError.httpError(_, data) {
            if let failure = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                throw Failure(code: failure.error, message: failure.message)
            }
            throw Failure(code: "unknown", message: "Couldn’t sign in just now. Please try again.")
        }
    }
}
