//
//  ClubService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Everything about clubs the app does (decision 25). Joining, leaving, requests, invites,
/// roles and ownership go through the database functions in
/// docs/migrations/2026-09-30-clubs.sql — the only way `profiles.club_id` / `club_role` can
/// change — so each rule is enforced on the server, not trusted to the app. A change to the
/// signed-in rower's own membership posts `.rowerClubChanged` so the feed, rankings and
/// profile reload.
enum ClubService {
    enum JoinOutcome: String, Decodable {
        /// In the club now (open club, or they were invited).
        case joined
        /// An approval club: the request waits for an admin.
        case requested
        /// Needs an invitation or the club's code.
        case inviteOnly = "invite_only"
    }

    /// The signed-in rower's club, role, join request and invitations.
    struct Membership {
        var club: Club?
        var role: ClubRole
        var memberCount: Int
        /// Their request to join a club, waiting or turned down (decision 26).
        var request: JoinRequest?
        /// Invitations still waiting for an answer.
        var invitations: [Club]
    }

    /// A rower's request to join an approval club.
    struct JoinRequest {
        let club: Club
        /// False while it waits; true once an admin has declined it.
        let isDeclined: Bool
    }

    /// Someone a club has invited, and whether they've turned it down (decision 26).
    struct Invitation: Identifiable {
        let person: Person
        let isDeclined: Bool
        var id: UUID { person.id }
    }

    /// A rower on a club's member, request or invite list.
    struct Person: Decodable, Identifiable {
        let id: UUID
        let displayName: String
        let role: ClubRole
        let category: RowerCategory

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case role = "club_role"
            case category
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            displayName = try c.decode(String.self, forKey: .displayName)
            role = try c.decodeIfPresent(ClubRole.self, forKey: .role) ?? .member
            category = try c.decode(RowerCategory.self, forKey: .category)
        }
    }

    private static let personColumns = "id, display_name, club_role, category"

    // MARK: - Reading

    static func membership() async throws -> Membership {
        let me = try await SupabaseService.shared.auth.session.user.id
        let profile: Profile = try await SupabaseService.shared
            .from("profiles").select().eq("id", value: me).single().execute().value

        var club: Club?
        var count = 0
        if let clubId = profile.clubId {
            club = try await SupabaseService.shared
                .from("clubs").select().eq("id", value: clubId).single().execute().value
            count = try await SupabaseService.shared
                .from("profiles").select("id", head: true, count: .exact)
                .eq("club_id", value: clubId).execute().count ?? 0
        }

        struct RequestRow: Decodable {
            let clubs: Club
            let status: String?
        }
        struct ClubRow: Decodable { let clubs: Club }
        let requests: [RequestRow] = (try? await SupabaseService.shared
            .from("club_join_requests").select("*, clubs(*)").eq("user_id", value: me).execute().value) ?? []
        let invites: [ClubRow] = (try? await SupabaseService.shared
            .from("club_invites").select("clubs(*)").eq("user_id", value: me).eq("status", value: "pending")
            .execute().value) ?? []

        return Membership(
            club: club,
            role: profile.clubRole,
            memberCount: count,
            request: requests.first.map { JoinRequest(club: $0.clubs, isDeclined: $0.status == "declined") },
            invitations: invites.map(\.clubs)
        )
    }

    /// Owner first, then co-owners, admins and members, each alphabetical.
    static func members(of clubId: UUID) async throws -> [Person] {
        let people: [Person] = try await SupabaseService.shared
            .from("profiles").select(personColumns).eq("club_id", value: clubId).execute().value
        return people.sorted {
            $0.role != $1.role ? $0.role > $1.role
                : $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    /// Rowers waiting to join `clubId`, oldest first. Admins and up only (the database hides
    /// them from everyone else).
    static func requests(for clubId: UUID) async throws -> [Person] {
        struct Row: Decodable { let profiles: Person }
        let rows: [Row] = try await SupabaseService.shared
            .from("club_join_requests").select("created_at, profiles(\(personColumns))")
            .eq("club_id", value: clubId).eq("status", value: "pending").order("created_at").execute().value
        return rows.map(\.profiles)
    }

    /// Rowers `clubId` has invited who haven't joined: waiting, or declined (decision 26).
    static func invitations(for clubId: UUID) async throws -> [Invitation] {
        struct Row: Decodable {
            let invitee: Person
            let status: String
        }
        let rows: [Row] = try await SupabaseService.shared
            .from("club_invites").select("status, invitee:profiles!club_invites_user_id_fkey(\(personColumns))")
            .eq("club_id", value: clubId).order("created_at", ascending: false).execute().value
        return rows.map { Invitation(person: $0.invitee, isDeclined: $0.status == "declined") }
    }

    // MARK: - Joining and leaving

    static func join(_ clubId: UUID) async throws -> JoinOutcome {
        struct Params: Encodable { let p_club: UUID }
        let outcome: JoinOutcome = try await SupabaseService.shared
            .rpc("join_club", params: Params(p_club: clubId)).execute().value
        if outcome == .joined { announce() }
        return outcome
    }

    @discardableResult
    static func join(code: String) async throws -> UUID {
        struct Params: Encodable { let p_code: String }
        let clubId: UUID = try await SupabaseService.shared
            .rpc("join_club_with_code", params: Params(p_code: code)).execute().value
        announce()
        return clubId
    }

    static func leave() async throws {
        try await SupabaseService.shared.rpc("leave_club").execute()
        announce()
    }

    /// Takes back a waiting request, or clears a declined one.
    static func cancelRequest() async throws {
        try await SupabaseService.shared.rpc("cancel_join_request").execute()
    }

    static func respondToInvitation(from clubId: UUID, accept: Bool) async throws {
        struct Params: Encodable { let p_club: UUID; let p_accept: Bool }
        try await SupabaseService.shared
            .rpc("respond_club_invite", params: Params(p_club: clubId, p_accept: accept)).execute()
        if accept { announce() }
    }

    // MARK: - Creating and editing

    struct Details: Encodable {
        let p_name: String
        let p_description: String
        let p_location: String
        let p_policy: ClubJoinPolicy
        let p_focus: ClubFocus
    }

    @discardableResult
    static func create(_ details: Details) async throws -> UUID {
        let clubId: UUID = try await SupabaseService.shared.rpc("create_club", params: details).execute().value
        announce()
        return clubId
    }

    static func update(_ details: Details) async throws {
        try await SupabaseService.shared.rpc("update_club", params: details).execute()
        announce()
    }

    // MARK: - Managing

    static func respondToRequest(from userId: UUID, accept: Bool) async throws {
        struct Params: Encodable { let p_user: UUID; let p_accept: Bool }
        try await SupabaseService.shared
            .rpc("respond_join_request", params: Params(p_user: userId, p_accept: accept)).execute()
    }

    static func invite(_ userId: UUID) async throws {
        try await SupabaseService.shared.rpc("invite_rower", params: UserParam(p_user: userId)).execute()
    }

    static func withdrawInvitation(to userId: UUID) async throws {
        try await SupabaseService.shared.rpc("withdraw_club_invite", params: UserParam(p_user: userId)).execute()
    }

    /// The club's code for "Have an invite code?"; `regenerate` replaces it, so the old one
    /// stops working.
    static func inviteCode(regenerate: Bool = false) async throws -> String {
        struct Params: Encodable { let p_new: Bool }
        return try await SupabaseService.shared
            .rpc("club_invite_code", params: Params(p_new: regenerate)).execute().value
    }

    static func setRole(_ role: ClubRole, for userId: UUID) async throws {
        struct Params: Encodable { let p_user: UUID; let p_role: ClubRole }
        try await SupabaseService.shared
            .rpc("set_club_role", params: Params(p_user: userId, p_role: role)).execute()
    }

    static func remove(_ userId: UUID) async throws {
        try await SupabaseService.shared.rpc("remove_club_member", params: UserParam(p_user: userId)).execute()
    }

    static func transferOwnership(to userId: UUID) async throws {
        try await SupabaseService.shared.rpc("transfer_club_ownership", params: UserParam(p_user: userId)).execute()
    }

    static func deleteClub() async throws {
        try await SupabaseService.shared.rpc("delete_club").execute()
        announce()
    }

    private struct UserParam: Encodable { let p_user: UUID }

    private static func announce() {
        NotificationCenter.default.postRowerClubChanged()
    }
}
