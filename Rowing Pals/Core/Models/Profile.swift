//
//  Profile.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `profiles` table in docs/schema.sql. One row per user, keyed
/// to Supabase's `auth.users`.
struct Profile: Codable, Identifiable {
    let id: UUID
    var displayName: String
    /// Their @username (decision 85); nil until chosen.
    var username: String?
    var clubId: UUID?
    /// Their role in that club (decision 25).
    var clubRole: ClubRole
    var gender: RowerGender?
    var category: RowerCategory
    var avatarPath: String?
    var weeklyTargetSessions: Int
    var weeklyTargetM: Int
    /// Redesign phase E. A private account's sessions and stats are visible
    /// only to approved followers; enforced in the database (see
    /// docs/migrations/2026-09-23-private-accounts.sql), not just hidden here.
    var isPrivate: Bool
    /// Set when onboarding finishes, with or without a club (decision 24).
    var onboardedAt: Date?
    /// Coaches their club (decision 39). Only the owner and co-owners change it, through
    /// `set_club_coach`; it ends when the club changes.
    var isCoach: Bool
    /// "I row" (true) or "Coach only" (false): a coach-only account has no gender or level, no
    /// Log button, and is never on a leaderboard or in Crewmates (decision 34).
    var isRower: Bool
    /// Stroke side, bow side or both (decision 67); nil until they pick one, and for coach-only
    /// accounts.
    var side: RowingSide?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case clubId = "club_id"
        case clubRole = "club_role"
        case gender, category
        case avatarPath = "avatar_path"
        case weeklyTargetSessions = "weekly_target_sessions"
        case weeklyTargetM = "weekly_target_m"
        case isPrivate = "is_private"
        case onboardedAt = "onboarded_at"
        case isCoach = "is_coach"
        case isRower = "is_rower"
        case side
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        // Absent before docs/migrations/2026-10-18-usernames.sql.
        username = try c.decodeIfPresent(String.self, forKey: .username)
        clubId = try c.decodeIfPresent(UUID.self, forKey: .clubId)
        // Absent before docs/migrations/2026-09-30-clubs.sql has run.
        clubRole = try c.decodeIfPresent(ClubRole.self, forKey: .clubRole) ?? .member
        gender = try c.decodeIfPresent(RowerGender.self, forKey: .gender)
        category = try c.decode(RowerCategory.self, forKey: .category)
        avatarPath = try c.decodeIfPresent(String.self, forKey: .avatarPath)
        weeklyTargetSessions = try c.decode(Int.self, forKey: .weeklyTargetSessions)
        weeklyTargetM = try c.decode(Int.self, forKey: .weeklyTargetM)
        // Absent means "public": a build running before the phase E migration
        // has been applied must not fail to decode every profile.
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        // Absent before docs/migrations/2026-09-29-onboarding.sql has run.
        onboardedAt = try c.decodeIfPresent(Date.self, forKey: .onboardedAt)
        // Absent before docs/migrations/2026-10-05-coaching.sql has run.
        isCoach = try c.decodeIfPresent(Bool.self, forKey: .isCoach) ?? false
        isRower = try c.decodeIfPresent(Bool.self, forKey: .isRower) ?? true
        // Absent before docs/migrations/2026-10-16-coach-version.sql has run.
        side = try c.decodeIfPresent(RowingSide.self, forKey: .side)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}
