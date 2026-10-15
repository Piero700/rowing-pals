//
//  DeclaredBestService.swift
//  Rowing Pals
//

import Foundation
import PaceEngine
import Supabase

/// Your bests (decision 64, docs/migrations/2026-10-15-declared-bests.sql): read and save the
/// signed-in rower's, read a coach's rowers', and turn them into the Pace Engine's input — an
/// all-out piece dated the day it was entered, flagged so it never counts as training.
enum DeclaredBestService {
    static func mine() async throws -> [DeclaredBest] {
        let userId = try await SupabaseService.shared.auth.session.user.id
        return try await SupabaseService.shared
            .from("declared_bests").select().eq("user_id", value: userId)
            .order("distance_m").execute().value
    }

    /// Replaces the rower's bests with `bests`. A best that hasn't changed keeps the day it was
    /// entered; a new or changed one is dated today (the rower's own day).
    static func save(_ bests: [(distanceM: Int, timeMs: Int)], previous: [DeclaredBest],
                     calendar: Calendar = .current) async throws {
        let userId = try await SupabaseService.shared.auth.session.user.id
        let today = PredictionService.isoDay(Date(), calendar: calendar)
        let rows = bests.map { best in
            let kept = previous.first { $0.distanceM == best.distanceM && $0.timeMs == best.timeMs }
            return DeclaredBest(id: kept?.id ?? UUID(), distanceM: best.distanceM, timeMs: best.timeMs,
                                setOn: kept?.setOn ?? today, userId: userId)
        }
        try await SupabaseService.shared.from("declared_bests").delete().eq("user_id", value: userId).execute()
        if !rows.isEmpty {
            try await SupabaseService.shared.from("declared_bests").insert(rows).execute()
        }
    }

    /// The rowers' bests a coach can read, by rower; empty before the migration.
    static func bests(for userIds: [UUID]) async -> [UUID: [DeclaredBest]] {
        guard !userIds.isEmpty else { return [:] }
        let rows: [DeclaredBest] = (try? await SupabaseService.shared
            .from("declared_bests").select().in("user_id", values: userIds).execute().value) ?? []
        return Dictionary(grouping: rows) { $0.userId ?? UUID() }
    }

    /// The engine's input: each best as one continuous all-out piece on the day it was entered.
    static func engineInputs(_ bests: [DeclaredBest], calendar: Calendar) -> [SessionInput] {
        bests.compactMap { best in
            guard let date = PredictionService.day(best.setOn, calendar: calendar) else { return nil }
            return SessionInput(
                id: "best-\(best.id.uuidString)",
                date: date,
                distanceM: Double(best.distanceM),
                tag: .an,
                timeS: Double(best.timeMs) / 1000,
                repDistanceM: Double(best.distanceM),
                declared: true
            )
        }
    }
}
