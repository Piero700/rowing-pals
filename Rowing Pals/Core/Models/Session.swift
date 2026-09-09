//
//  Session.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `sessions` table in docs/schema.sql. One training outing,
/// with the segment breakdown rolled up onto this row so the feed needs
/// only one query.
struct Session: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var type: SessionType
    var caption: String?

    var totalDistanceM: Int
    var totalTimeMs: Int
    var avgSplitMs: Int?
    var avgRate: Double?

    var photoVerified: Bool
    var loggedLate: Bool

    var capturedAt: Date
    let postedAt: Date

    /// The user's local calendar day (Postgres `date`, no time component).
    /// Kept as a plain "yyyy-MM-dd" string rather than `Date` — decoding a
    /// bare date into `Date` invites exactly the UTC-shift bug CLAUDE.md
    /// warns about for streaks and charts.
    var sessionDate: String

    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type, caption
        case totalDistanceM = "total_distance_m"
        case totalTimeMs = "total_time_ms"
        case avgSplitMs = "avg_split_ms"
        case avgRate = "avg_rate"
        case photoVerified = "photo_verified"
        case loggedLate = "logged_late"
        case capturedAt = "captured_at"
        case postedAt = "posted_at"
        case sessionDate = "session_date"
        case createdAt = "created_at"
    }
}
