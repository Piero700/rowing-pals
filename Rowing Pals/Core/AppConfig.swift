//
//  AppConfig.swift
//  Rowing Pals
//

import Foundation

/// Reads per-build-configuration values surfaced into Info.plist from the
/// active `Config/*.xcconfig` file. Never hardcode a Supabase URL or key —
/// they come from here.
enum AppConfig {
    static var supabaseURL: URL {
        guard let value = string(for: "SUPABASE_URL"), let url = URL(string: value) else {
            fatalError("SUPABASE_URL missing or invalid in Info.plist — check the active .xcconfig is wired up.")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let value = string(for: "SUPABASE_ANON_KEY"), !value.isEmpty else {
            fatalError("SUPABASE_ANON_KEY missing in Info.plist — check the active .xcconfig is wired up.")
        }
        return value
    }

    private static func string(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
