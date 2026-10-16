//
//  AccountService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Signing out, from Settings or the coach's Profile.
enum AccountService {
    /// While still signed in, this phone stops getting the account's alerts; then it signs out.
    static func signOut() async {
        await PushNotificationService.shared.unregisterThisDevice()
        try? await SupabaseService.shared.auth.signOut()
    }
}
