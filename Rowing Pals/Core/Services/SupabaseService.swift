//
//  SupabaseService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// The app's single Supabase client, built from `AppConfig` — never a
/// hardcoded URL or key.
enum SupabaseService {
    static let shared = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}
