//
//  NotepadService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// The coach notepad (decision 96; docs/migrations/2026-11-05-coach-notepad.sql). Every coach in
/// the workout's club reads and edits its page; rowers can't read it. Writes go through the
/// server's functions, which check the caller coaches the workout's club.
enum NotepadService {
    /// The workout's page, or nil before any coach has changed it.
    static func notepad(for workoutId: UUID) async throws -> CoachNotepad? {
        let rows: [CoachNotepad] = try await SupabaseService.shared
            .from("coach_notepads").select("workout_id, club_id, blocks, notes, rower_order")
            .eq("workout_id", value: workoutId)
            .execute().value
        return rows.first
    }

    /// Every score the club's coaches have put on the workout's page.
    static func scores(for workoutId: UUID) async throws -> [NotepadScore] {
        try await SupabaseService.shared
            .from("coach_notepad_scores")
            .select("workout_id, user_id, piece_index, split_ms, time_ms, distance_m, rate, sat_out, source")
            .eq("workout_id", value: workoutId)
            .execute().value
    }

    /// Saves the page's blocks, Notes and erg order (the page is made on its first save).
    static func savePage(workoutId: UUID, blocks: [NotepadBlock], notes: String, rowerOrder: [UUID]) async throws {
        struct Params: Encodable {
            let p_workout: UUID
            let p_blocks: [NotepadBlock]
            let p_notes: String
            let p_rower_order: [UUID]
        }
        try await SupabaseService.shared.rpc("save_notepad", params: Params(
            p_workout: workoutId, p_blocks: blocks, p_notes: notes, p_rower_order: rowerOrder
        )).execute()
    }

    /// Saves one rower's score for one rep: a split, or sat out.
    static func saveScore(_ score: NotepadScore) async throws {
        struct Params: Encodable {
            let p_workout: UUID
            let p_user: UUID
            let p_piece: Int
            let p_split_ms: Int?
            let p_time_ms: Int?
            let p_distance_m: Int?
            let p_rate: Int?
            let p_sat_out: Bool
            let p_source: String
            // Nil values go as JSON null, so the function's every argument is always named.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_workout, forKey: .p_workout)
                try c.encode(p_user, forKey: .p_user)
                try c.encode(p_piece, forKey: .p_piece)
                try c.encode(p_split_ms, forKey: .p_split_ms)
                try c.encode(p_time_ms, forKey: .p_time_ms)
                try c.encode(p_distance_m, forKey: .p_distance_m)
                try c.encode(p_rate, forKey: .p_rate)
                try c.encode(p_sat_out, forKey: .p_sat_out)
                try c.encode(p_source, forKey: .p_source)
            }
            enum Keys: String, CodingKey {
                case p_workout, p_user, p_piece, p_split_ms, p_time_ms, p_distance_m, p_rate, p_sat_out, p_source
            }
        }
        try await SupabaseService.shared.rpc("save_notepad_score", params: Params(
            p_workout: score.workoutId, p_user: score.userId, p_piece: score.pieceIndex,
            p_split_ms: score.splitMs, p_time_ms: score.timeMs, p_distance_m: score.distanceM,
            p_rate: score.rate, p_sat_out: score.satOut, p_source: score.source.rawValue
        )).execute()
    }

    /// Takes a score off the page: the box goes back to the rower's own post, or empty.
    static func deleteScore(workoutId: UUID, userId: UUID, pieceIndex: Int) async throws {
        struct Params: Encodable {
            let p_workout: UUID
            let p_user: UUID
            let p_piece: Int
        }
        try await SupabaseService.shared.rpc("delete_notepad_score", params: Params(
            p_workout: workoutId, p_user: userId, p_piece: pieceIndex
        )).execute()
    }
}
