//
//  SessionType.swift
//  Rowing Pals
//

/// Mirrors the `session_type` enum in docs/schema.sql. The app logs erg sessions only: water
/// logging was removed (decision 54); the database's 'water' value stays unused.
enum SessionType: String, Codable {
    case erg
}
