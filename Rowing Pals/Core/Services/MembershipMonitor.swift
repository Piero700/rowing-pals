//
//  MembershipMonitor.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Notices when the signed-in rower's own club changes *anywhere* — an admin accepting their
/// request on another phone, removing them, changing their role, declining — and posts
/// `.rowerClubChanged` so the feed, rankings and profile reload. Without it, only changes made
/// on this phone reached those screens, so an accepted rower still read "You're not in a club"
/// (decision 26). Runs from `RootView` on live updates and whenever the app comes back.
@MainActor
final class MembershipMonitor {
    private struct Snapshot: Equatable {
        let clubId: UUID?
        let role: String?
        let request: String?
    }

    private var last: Snapshot?

    /// Checks on every live club change for as long as the caller's task runs.
    func run() async {
        await check()
        for await _ in ClubLiveUpdates.changes() {
            await check()
        }
    }

    /// Compares the rower's club, role and request with last time; posts if any changed.
    func check() async {
        guard let now = await Self.snapshot() else { return }
        if let last, last != now {
            NotificationCenter.default.postRowerClubChanged()
        }
        last = now
    }

    private static func snapshot() async -> Snapshot? {
        guard let me = try? await SupabaseService.shared.auth.session.user.id else { return nil }
        struct ProfileRow: Decodable {
            let club_id: UUID?
            let club_role: String?
        }
        struct RequestRow: Decodable {
            let club_id: UUID
            let status: String?
        }
        guard let profile: ProfileRow = try? await SupabaseService.shared
            .from("profiles").select("*").eq("id", value: me).single().execute().value else { return nil }
        let requests: [RequestRow] = (try? await SupabaseService.shared
            .from("club_join_requests").select("*").eq("user_id", value: me).execute().value) ?? []
        let request = requests.first.map { "\($0.club_id) \($0.status ?? "pending")" }
        return Snapshot(clubId: profile.club_id, role: profile.club_role, request: request)
    }
}
