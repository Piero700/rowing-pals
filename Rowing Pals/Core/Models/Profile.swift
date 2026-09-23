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
    var clubId: UUID?
    var gender: RowerGender?
    var category: RowerCategory
    var avatarPath: String?
    var weeklyTargetSessions: Int
    var weeklyTargetM: Int
    /// Redesign phase E. A private account's sessions and stats are visible
    /// only to approved followers; enforced in the database (see
    /// docs/migrations/2026-09-23-private-accounts.sql), not just hidden here.
    var isPrivate: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case clubId = "club_id"
        case gender, category
        case avatarPath = "avatar_path"
        case weeklyTargetSessions = "weekly_target_sessions"
        case weeklyTargetM = "weekly_target_m"
        case isPrivate = "is_private"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        clubId = try c.decodeIfPresent(UUID.self, forKey: .clubId)
        gender = try c.decodeIfPresent(RowerGender.self, forKey: .gender)
        category = try c.decode(RowerCategory.self, forKey: .category)
        avatarPath = try c.decodeIfPresent(String.self, forKey: .avatarPath)
        weeklyTargetSessions = try c.decode(Int.self, forKey: .weeklyTargetSessions)
        weeklyTargetM = try c.decode(Int.self, forKey: .weeklyTargetM)
        // Absent means "public": a build running before the phase E migration
        // has been applied must not fail to decode every profile.
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}
