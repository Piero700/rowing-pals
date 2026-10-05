//
//  ViewerContext.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Who the signed-in rower is — name, gender, level, club, clubmates and who they follow —
/// fetched once and shared by every screen, instead of each screen asking the database again
/// before it can ask for what it shows. One round for the profile and follows together, one
/// for the clubmates.
///
/// Refetched when it may have changed: joining or leaving a club (`postRowerClubChanged()`),
/// following or unfollowing, editing the profile, signing in or out, a pull to refresh, and in
/// any case after `maxAge`, so a follow request someone accepts elsewhere still shows up.
final class ViewerContext {
    struct Snapshot: Equatable {
        let userId: UUID
        let displayName: String
        let gender: RowerGender?
        let category: RowerCategory
        let clubId: UUID?
        let clubName: String?
        /// Everyone in the viewer's club, the viewer included; empty without a club.
        let clubmateIds: [UUID]
        /// Accepted follows only — a pending request is not a follow.
        let followingIds: [UUID]
    }

    static let shared = ViewerContext()

    static let maxAge: Duration = .seconds(120)

    private var snapshot: Snapshot?
    private var fetchedAt: ContinuousClock.Instant?
    private var inFlight: Task<Snapshot, Error>?
    /// Bumped by `invalidate()`, so a fetch that started before it can't store stale data.
    private var generation = 0

    private init() {}

    /// The current snapshot, fetching it if there is none or it's older than `maxAge`.
    /// Concurrent callers share one fetch.
    func current() async throws -> Snapshot {
        if let snapshot, let fetchedAt, ContinuousClock.now - fetchedAt < Self.maxAge {
            return snapshot
        }
        if let inFlight { return try await inFlight.value }
        let startedGeneration = generation
        let task = Task { try await Self.fetch() }
        inFlight = task
        defer { if generation == startedGeneration { inFlight = nil } }
        let fresh = try await task.value
        if generation == startedGeneration {
            snapshot = fresh
            fetchedAt = .now
        }
        return fresh
    }

    /// Forgets the snapshot; the next `current()` fetches a new one.
    func invalidate() {
        generation += 1
        snapshot = nil
        fetchedAt = nil
        inFlight = nil
    }

    private static func fetch() async throws -> Snapshot {
        let userId = try await SupabaseService.shared.auth.session.user.id

        nonisolated struct ProfileRow: Decodable {
            struct Club: Decodable { let name: String }
            let displayName: String
            let gender: RowerGender?
            let category: RowerCategory
            let clubId: UUID?
            let club: Club?
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case gender, category
                case clubId = "club_id"
                case club = "clubs"
            }
        }
        nonisolated struct FollowRow: Decodable {
            let followeeId: UUID
            enum CodingKeys: String, CodingKey { case followeeId = "followee_id" }
        }
        async let profileRow: ProfileRow = SupabaseService.shared
            .from("profiles")
            .select("display_name, gender, category, club_id, clubs(name)")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        async let followRows: [FollowRow] = SupabaseService.shared
            .from("follows")
            .select("followee_id")
            .eq("follower_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value
        let (profile, follows) = try await (profileRow, followRows)

        var clubmateIds: [UUID] = []
        if let clubId = profile.clubId {
            nonisolated struct MemberRow: Decodable { let id: UUID }
            let members: [MemberRow] = try await SupabaseService.shared
                .from("profiles")
                .select("id")
                .eq("club_id", value: clubId)
                .execute()
                .value
            clubmateIds = members.map(\.id)
        }

        return Snapshot(
            userId: userId,
            displayName: profile.displayName,
            gender: profile.gender,
            category: profile.category,
            clubId: profile.clubId,
            clubName: profile.club?.name,
            clubmateIds: clubmateIds,
            followingIds: follows.map(\.followeeId)
        )
    }
}
