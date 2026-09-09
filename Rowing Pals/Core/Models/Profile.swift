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
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case clubId = "club_id"
        case gender, category
        case avatarPath = "avatar_path"
        case weeklyTargetSessions = "weekly_target_sessions"
        case createdAt = "created_at"
    }
}
