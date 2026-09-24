//
//  FollowService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// How the signed-in viewer relates to another rower. `requested` only ever
/// applies to a private account: the database, not this client, decides
/// whether a new follow is `pending` or `accepted`
/// (docs/migrations/2026-09-23-private-accounts.sql).
enum FollowState: Equatable {
    case notFollowing, requested, following
}

/// A rower as shown in a list row — name, club, level, privacy — and
/// nothing about their training.
struct PersonSummary: Identifiable, Decodable, Equatable {
    struct Club: Decodable, Equatable { let name: String }

    let id: UUID
    let displayName: String
    let category: RowerCategory
    let isPrivate: Bool
    let avatarPath: String?
    let club: Club?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case category
        case isPrivate = "is_private"
        case avatarPath = "avatar_path"
        case club = "clubs"
    }

    static let selectColumns = "id, display_name, category, is_private, avatar_path, clubs(name)"
}

/// All follow, follow-request and people-list queries in one place, so every
/// screen agrees on what `follows.status` means. Every read here is also
/// filtered by row-level security, so a private account's lists come back
/// empty for anyone not approved even if a screen forgot to check first.
enum FollowService {
    private struct FollowRow: Decodable {
        let followerId: UUID
        let followeeId: UUID
        let status: String
        enum CodingKeys: String, CodingKey {
            case followerId = "follower_id"
            case followeeId = "followee_id"
            case status
        }
    }

    private static func currentUserId() async throws -> UUID {
        try await SupabaseService.shared.auth.session.user.id
    }

    // MARK: - Relationship

    /// The viewer's relationship to `target`.
    static func state(to target: UUID) async throws -> FollowState {
        let me = try await currentUserId()
        let rows: [FollowRow] = try await SupabaseService.shared
            .from("follows")
            .select("follower_id, followee_id, status")
            .eq("follower_id", value: me)
            .eq("followee_id", value: target)
            .execute()
            .value
        guard let row = rows.first else { return .notFollowing }
        return row.status == "accepted" ? .following : .requested
    }

    /// Whether `target` follows the viewer (approved) — drives the
    /// "Follow back" label.
    static func isFollowedBy(_ target: UUID) async throws -> Bool {
        let me = try await currentUserId()
        let rows: [FollowRow] = try await SupabaseService.shared
            .from("follows")
            .select("follower_id, followee_id, status")
            .eq("follower_id", value: target)
            .eq("followee_id", value: me)
            .eq("status", value: "accepted")
            .execute()
            .value
        return !rows.isEmpty
    }

    /// Follows (or requests to follow) `target`. Returns the resulting state
    /// read back from the database, because whether it became `pending` or
    /// `accepted` is decided server-side.
    @discardableResult
    static func follow(_ target: UUID) async throws -> FollowState {
        let me = try await currentUserId()
        struct NewFollow: Encodable {
            let followerId: UUID
            let followeeId: UUID
            enum CodingKeys: String, CodingKey {
                case followerId = "follower_id"
                case followeeId = "followee_id"
            }
        }
        try await SupabaseService.shared
            .from("follows")
            .insert(NewFollow(followerId: me, followeeId: target))
            .execute()
        return try await state(to: target)
    }

    /// Unfollows, or cancels a pending request — the same delete.
    static func unfollow(_ target: UUID) async throws {
        let me = try await currentUserId()
        try await SupabaseService.shared
            .from("follows")
            .delete()
            .eq("follower_id", value: me)
            .eq("followee_id", value: target)
            .execute()
    }

    // MARK: - Requests (the viewer is the one being asked)

    static func pendingRequestCount() async throws -> Int {
        let me = try await currentUserId()
        let response = try await SupabaseService.shared
            .from("follows")
            .select("follower_id", head: true, count: .exact)
            .eq("followee_id", value: me)
            .eq("status", value: "pending")
            .execute()
        return response.count ?? 0
    }

    static func pendingRequests() async throws -> [PersonSummary] {
        let me = try await currentUserId()
        let rows: [FollowRow] = try await SupabaseService.shared
            .from("follows")
            .select("follower_id, followee_id, status")
            .eq("followee_id", value: me)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        return try await people(ids: rows.map(\.followerId))
    }

    /// Approves a request. Only `status` can change — the database refuses
    /// anything else.
    static func accept(follower: UUID) async throws {
        let me = try await currentUserId()
        struct Update: Encodable { let status = "accepted" }
        try await SupabaseService.shared
            .from("follows")
            .update(Update())
            .eq("follower_id", value: follower)
            .eq("followee_id", value: me)
            .execute()
    }

    /// Declines a request, or removes an existing follower — the same delete.
    static func decline(follower: UUID) async throws {
        let me = try await currentUserId()
        try await SupabaseService.shared
            .from("follows")
            .delete()
            .eq("follower_id", value: follower)
            .eq("followee_id", value: me)
            .execute()
    }

    // MARK: - Counts and lists (approved follows only)

    static func counts(for user: UUID) async throws -> (followers: Int, following: Int) {
        async let followers = SupabaseService.shared
            .from("follows")
            .select("follower_id", head: true, count: .exact)
            .eq("followee_id", value: user)
            .eq("status", value: "accepted")
            .execute()
        async let following = SupabaseService.shared
            .from("follows")
            .select("followee_id", head: true, count: .exact)
            .eq("follower_id", value: user)
            .eq("status", value: "accepted")
            .execute()
        let (a, b) = try await (followers, following)
        return (a.count ?? 0, b.count ?? 0)
    }

    static func followers(of user: UUID) async throws -> [PersonSummary] {
        let rows: [FollowRow] = try await SupabaseService.shared
            .from("follows")
            .select("follower_id, followee_id, status")
            .eq("followee_id", value: user)
            .eq("status", value: "accepted")
            .order("created_at", ascending: false)
            .execute()
            .value
        return try await people(ids: rows.map(\.followerId))
    }

    static func following(of user: UUID) async throws -> [PersonSummary] {
        let rows: [FollowRow] = try await SupabaseService.shared
            .from("follows")
            .select("follower_id, followee_id, status")
            .eq("follower_id", value: user)
            .eq("status", value: "accepted")
            .order("created_at", ascending: false)
            .execute()
            .value
        return try await people(ids: rows.map(\.followeeId))
    }

    /// The set of people the viewer follows or has requested, keyed to their
    /// state — one query for a whole list, instead of one per row.
    static func viewerStates() async throws -> [UUID: FollowState] {
        let me = try await currentUserId()
        let rows: [FollowRow] = try await SupabaseService.shared
            .from("follows")
            .select("follower_id, followee_id, status")
            .eq("follower_id", value: me)
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map {
            ($0.followeeId, $0.status == "accepted" ? FollowState.following : .requested)
        })
    }

    // MARK: - Find rowers

    /// Name search for the Find rowers screen. Excludes the viewer and
    /// anyone on either side of a block.
    static func search(_ query: String) async throws -> [PersonSummary] {
        let me = try await currentUserId()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = SupabaseService.shared
            .from("profiles")
            .select(PersonSummary.selectColumns)
            .neq("id", value: me)
        if !trimmed.isEmpty {
            request = request.ilike("display_name", pattern: "%\(trimmed)%")
        }
        let found: [PersonSummary] = try await request
            .order("display_name", ascending: true)
            .limit(40)
            .execute()
            .value

        struct BlockRow: Decodable {
            let blockerId: UUID
            let blockedId: UUID
            enum CodingKeys: String, CodingKey {
                case blockerId = "blocker_id"
                case blockedId = "blocked_id"
            }
        }
        let blocks: [BlockRow] = (try? await SupabaseService.shared
            .from("blocks")
            .select("blocker_id, blocked_id")
            .execute()
            .value) ?? []
        let hidden = Set(blocks.flatMap { [$0.blockerId, $0.blockedId] })
        return found.filter { !hidden.contains($0.id) }
    }

    // MARK: - Shared

    /// Profiles for a list of ids, in the order given. Empty in, empty out —
    /// an `in` filter with no values is an error in PostgREST.
    private static func people(ids: [UUID]) async throws -> [PersonSummary] {
        guard !ids.isEmpty else { return [] }
        let fetched: [PersonSummary] = try await SupabaseService.shared
            .from("profiles")
            .select(PersonSummary.selectColumns)
            .in("id", values: ids)
            .execute()
            .value
        let byId = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        return ids.compactMap { byId[$0] }
    }
}
