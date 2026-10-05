//
//  NotificationSettings.swift
//  Rowing Pals
//

import Foundation

/// Mirrors `notification_settings` (docs/migrations/2026-09-26-notifications.sql): which
/// alerts a rower wants. A rower with no row gets `defaults(for:)`, the same values as the
/// table's column defaults. Quiet hours were removed (decision 36); their columns are unused.
nonisolated struct NotificationSettings: Codable, Equatable {
    let userId: UUID
    /// Someone comments on your post, or on a post you've commented on.
    var comments: Bool
    /// You, or someone you follow, sets a new personal best.
    var personalBests: Bool
    /// A clubmate posts.
    var clubActivity: Bool
    /// A coach sets a workout for you (decision 36).
    var newWorkouts: Bool

    static func defaults(for userId: UUID) -> NotificationSettings {
        NotificationSettings(userId: userId, comments: true, personalBests: true, clubActivity: false, newWorkouts: true)
    }

    init(userId: UUID, comments: Bool, personalBests: Bool, clubActivity: Bool, newWorkouts: Bool) {
        self.userId = userId
        self.comments = comments
        self.personalBests = personalBests
        self.clubActivity = clubActivity
        self.newWorkouts = newWorkouts
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case comments
        case personalBests = "personal_bests"
        case clubActivity = "club_activity"
        case newWorkouts = "new_workouts"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(UUID.self, forKey: .userId)
        comments = try c.decode(Bool.self, forKey: .comments)
        personalBests = try c.decode(Bool.self, forKey: .personalBests)
        clubActivity = try c.decode(Bool.self, forKey: .clubActivity)
        // Absent before the coaching migration's Phase 2 section has run.
        newWorkouts = try c.decodeIfPresent(Bool.self, forKey: .newWorkouts) ?? true
    }
}
