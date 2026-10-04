//
//  ClubLiveUpdates.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Live club changes (decision 26), so club pages update without leaving and coming back:
/// a membership, club, join request or invitation changed somewhere the signed-in rower may
/// see it. Supabase Realtime sends each change (the tables join its feed in
/// docs/migrations/2026-10-04-club-updates.sql, and it only sends rows the rower's own access
/// rules allow); a burst of changes arrives as one tick, so a page reloads once.
enum ClubLiveUpdates {
    static func changes() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                let channel = SupabaseService.shared.channel("clubs-\(UUID().uuidString)")
                let streams = ["profiles", "clubs", "club_join_requests", "club_invites"].map {
                    channel.postgresChange(AnyAction.self, schema: "public", table: $0)
                }
                do {
                    try await channel.subscribeWithError()
                } catch {
                    // Live updates are a convenience: without them, pull to refresh still works.
                }
                await withTaskGroup(of: Void.self) { group in
                    for stream in streams {
                        group.addTask {
                            for await _ in stream { continuation.yield() }
                        }
                    }
                }
                await SupabaseService.shared.removeChannel(channel)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
