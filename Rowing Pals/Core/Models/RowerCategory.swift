//
//  RowerCategory.swift
//  Rowing Pals
//

/// Mirrors the `rower_category` enum in docs/schema.sql. Experience level in
/// UK university rowing, not age — a novice is in their first season.
enum RowerCategory: String, Codable {
    case novice
    case senior
}
