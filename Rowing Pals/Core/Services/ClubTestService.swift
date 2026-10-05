//
//  ClubTestService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Club tests (decision 28): reading a club's tests, and adding or deleting one through the
/// database functions in docs/migrations/2026-10-04-club-tests.sql, which only admins and up
/// may call.
enum ClubTestService {
    /// The signed-in rower's club tests, and whether they may add or delete them.
    struct MyClubTests {
        let clubId: UUID?
        let canManage: Bool
        let tests: [ClubTest]

        static let none = MyClubTests(clubId: nil, canManage: false, tests: [])
    }

    private static let columns = "id, club_id, label, distance_m, duration_ms"

    static func mine() async throws -> MyClubTests {
        struct Me: Decodable {
            let clubId: UUID?
            let clubRole: ClubRole?
            enum CodingKeys: String, CodingKey {
                case clubId = "club_id"
                case clubRole = "club_role"
            }
        }
        let userId = try await SupabaseService.shared.auth.session.user.id
        let me: Me = try await SupabaseService.shared
            .from("profiles").select("club_id, club_role").eq("id", value: userId).single().execute().value
        guard let clubId = me.clubId else { return .none }
        let tests: [ClubTest] = try await SupabaseService.shared
            .from("club_tests").select(columns).eq("club_id", value: clubId).execute().value
        return MyClubTests(
            clubId: clubId,
            canManage: (me.clubRole ?? .member).canManageMembers,
            tests: ClubTest.sorted(tests)
        )
    }

    /// The club test a result's `distance_key` names, or nil for a standard key or a deleted test.
    static func test(forKey key: String) async throws -> ClubTest? {
        guard key.hasPrefix(ClubTest.keyPrefix),
              let id = UUID(uuidString: String(key.dropFirst(ClubTest.keyPrefix.count))) else { return nil }
        let rows: [ClubTest] = try await SupabaseService.shared
            .from("club_tests").select(columns).eq("id", value: id).execute().value
        return rows.first
    }

    /// Exactly one of `distanceM` or `minutes`. The database names it and rejects a duplicate.
    @discardableResult
    static func create(distanceM: Int?, minutes: Int?) async throws -> UUID {
        struct Params: Encodable {
            let p_distance_m: Int?
            let p_duration_ms: Int?

            // Both keys always sent: the function takes both, one of them null.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_distance_m, forKey: .p_distance_m)
                try c.encode(p_duration_ms, forKey: .p_duration_ms)
            }
            enum CodingKeys: String, CodingKey { case p_distance_m, p_duration_ms }
        }
        return try await SupabaseService.shared
            .rpc("create_club_test", params: Params(p_distance_m: distanceM, p_duration_ms: minutes.map { $0 * 60_000 }))
            .execute().value
    }

    /// Deletes the test and every result posted to it.
    static func delete(_ testId: UUID) async throws {
        struct Params: Encodable { let p_test: UUID }
        try await SupabaseService.shared.rpc("delete_club_test", params: Params(p_test: testId)).execute()
    }
}
