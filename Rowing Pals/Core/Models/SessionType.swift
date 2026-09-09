//
//  SessionType.swift
//  Rowing Pals
//

/// Mirrors the `session_type` enum in docs/schema.sql.
enum SessionType: String, Codable {
    case erg
    case water
}
