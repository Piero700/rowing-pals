//
//  AccountService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Signing out, from Settings or the coach's Profile, and deleting the account (Settings, or the
/// date of birth question for someone under 13 — decision 107).
enum AccountService {
    /// While still signed in, this phone stops getting the account's alerts; then it signs out.
    static func signOut() async {
        await PushNotificationService.shared.unregisterThisDevice()
        try? await SupabaseService.shared.auth.signOut()
    }

    /// Deletion happens entirely server-side, in the `delete-account` Edge Function — deleting the
    /// `auth.users` row needs the service-role key, which never ships in the client. That row's
    /// cascade takes every table with it; the function also clears the two Storage buckets, which no
    /// foreign key reaches.
    ///
    /// Signing out afterwards isn't just tidiness: an admin-side deletion doesn't revoke the
    /// caller's already-issued token, so without it the app would sit on a session for an account
    /// that no longer exists until the token expires.
    static func deleteAccount() async throws {
        try await SupabaseService.shared.functions.invoke("delete-account")
        await signOut()
    }
}
