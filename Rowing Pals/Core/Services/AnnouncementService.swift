//
//  AnnouncementService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Announcements (decision 75; docs/migrations/2026-10-17-rigging-and-announcements.sql). Everyone
/// in the club reads them; coaches post; coaches, the owner and co-owners edit and delete.
enum AnnouncementService {
    /// The club's announcements still on the Feed, or that came off it since `since`; newest first.
    static func club(since: Date) async throws -> [Announcement] {
        guard let clubId = try await ViewerContext.shared.current().clubId else { return [] }
        return try await SupabaseService.shared
            .from("announcements").select().eq("club_id", value: clubId)
            .gte("expires_at", value: CalendarService.iso(since))
            .order("created_at", ascending: false)
            .execute().value
    }

    /// The ones on rowers' Feeds now.
    static func live(now: Date = Date()) async throws -> [Announcement] {
        AnnouncementRules.live(try await club(since: now), now: now)
    }

    static func announcement(_ id: UUID) async throws -> Announcement {
        try await SupabaseService.shared.from("announcements").select().eq("id", value: id).single().execute().value
    }

    /// Posts one; `alert` also tells every rower. Returns its id.
    @discardableResult
    static func post(heading: String, message: String, expiresAt: Date, alert: Bool) async throws -> UUID {
        struct Params: Encodable {
            let p_heading: String
            let p_message: String?
            let p_expires_at: String
            let p_alert: Bool
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_heading, forKey: .p_heading)
                try c.encode(p_message, forKey: .p_message)
                try c.encode(p_expires_at, forKey: .p_expires_at)
                try c.encode(p_alert, forKey: .p_alert)
            }
            enum Keys: String, CodingKey { case p_heading, p_message, p_expires_at, p_alert }
        }
        return try await SupabaseService.shared.rpc("post_announcement", params: Params(
            p_heading: heading.trimmingCharacters(in: .whitespacesAndNewlines), p_message: trimmed(message),
            p_expires_at: CalendarService.iso(expiresAt), p_alert: alert
        )).execute().value
    }

    static func update(_ id: UUID, heading: String, message: String, expiresAt: Date) async throws {
        struct Params: Encodable {
            let p_announcement: UUID
            let p_heading: String
            let p_message: String?
            let p_expires_at: String
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_announcement, forKey: .p_announcement)
                try c.encode(p_heading, forKey: .p_heading)
                try c.encode(p_message, forKey: .p_message)
                try c.encode(p_expires_at, forKey: .p_expires_at)
            }
            enum Keys: String, CodingKey { case p_announcement, p_heading, p_message, p_expires_at }
        }
        try await SupabaseService.shared.rpc("update_announcement", params: Params(
            p_announcement: id, p_heading: heading.trimmingCharacters(in: .whitespacesAndNewlines),
            p_message: trimmed(message), p_expires_at: CalendarService.iso(expiresAt)
        )).execute()
    }

    static func delete(_ id: UUID) async throws {
        struct Params: Encodable { let p_announcement: UUID }
        try await SupabaseService.shared.rpc("delete_announcement", params: Params(p_announcement: id)).execute()
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
