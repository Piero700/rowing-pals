//
//  TestResult.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `test_results` table in docs/schema.sql. Created only when
/// the user confirms the test-detection prompt.
///
/// `genderAtTime`/`categoryAtTime` are snapshots, never live joins to
/// `Profile` — category is self-declared and changeable, so reading it live
/// would let one setting change silently rewrite the leaderboards.
struct TestResult: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var sessionId: UUID
    var segmentId: UUID

    /// '500m','1k','2k','5k','6k','10k','4min','30min','60min'.
    var distanceKey: String
    var distanceM: Int
    var timeMs: Int
    var splitMs: Int

    var genderAtTime: RowerGender
    var categoryAtTime: RowerCategory

    let setAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionId = "session_id"
        case segmentId = "segment_id"
        case distanceKey = "distance_key"
        case distanceM = "distance_m"
        case timeMs = "time_ms"
        case splitMs = "split_ms"
        case genderAtTime = "gender_at_time"
        case categoryAtTime = "category_at_time"
        case setAt = "set_at"
    }
}
