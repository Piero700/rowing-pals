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
            .select("workout_id, user_id, piece_index, split_ms, time_ms, distance_m, rate, sat_out, source, splits_500_ms")
            .eq("workout_id", value: workoutId)
            .execute().value
    }

    /// Every notepad page among these workouts (NP4's Notebook).
    static func notepads(for workoutIds: [UUID]) async throws -> [CoachNotepad] {
        guard !workoutIds.isEmpty else { return [] }
        return try await SupabaseService.shared
            .from("coach_notepads").select("workout_id, club_id, blocks, notes, rower_order")
            .in("workout_id", values: workoutIds)
            .execute().value
    }

    /// Every score the club's coaches noted on these workouts (NP4's Notebook).
    static func scores(for workoutIds: [UUID]) async throws -> [NotepadScore] {
        guard !workoutIds.isEmpty else { return [] }
        return try await SupabaseService.shared
            .from("coach_notepad_scores")
            .select("workout_id, user_id, piece_index, split_ms, time_ms, distance_m, rate, sat_out, source")
            .in("workout_id", values: workoutIds)
            .execute().value
    }

    /// The scores the signed-in rower's coaches noted for them on workouts since `since`
    /// ("yyyy-MM-dd"), one entry per workout, newest first (NP4's Feed card). Only their own scores:
    /// `my_notepad_scores` never returns anyone else's, or any page's text, tables or Notes.
    static func myScores(since: String) async throws -> [CoachNotedScores] {
        nonisolated struct Row: Decodable {
            let workoutId: UUID
            let title: String
            let workoutDate: String
            let pieces: [WorkoutPiece]?
            let testKey: String?
            let coachName: String?
            let clubName: String?
            let erg: Int?
            let pieceIndex: Int
            let splitMs: Int?
            let satOut: Bool
            let postedAvgSplitMs: Int?
            enum CodingKeys: String, CodingKey {
                case title, pieces, erg
                case workoutId = "workout_id"
                case workoutDate = "workout_date"
                case testKey = "test_key"
                case coachName = "coach_name"
                case clubName = "club_name"
                case pieceIndex = "piece_index"
                case splitMs = "split_ms"
                case satOut = "sat_out"
                case postedAvgSplitMs = "posted_avg_split_ms"
            }
        }
        struct Params: Encodable { let p_since: String }
        let rows: [Row] = try await SupabaseService.shared
            .rpc("my_notepad_scores", params: Params(p_since: since))
            .execute().value
        var order: [UUID] = []
        var byWorkout: [UUID: [Row]] = [:]
        for row in rows {
            if byWorkout[row.workoutId] == nil { order.append(row.workoutId) }
            byWorkout[row.workoutId, default: []].append(row)
        }
        return order.compactMap { id in
            guard let group = byWorkout[id], let first = group.first else { return nil }
            return CoachNotedScores(
                workoutId: id, title: first.title, workoutDate: first.workoutDate, pieces: first.pieces ?? [],
                testKey: first.testKey, coachName: first.coachName, clubName: first.clubName, erg: first.erg,
                scores: group.sorted { $0.pieceIndex < $1.pieceIndex }
                    .map { CoachNotedScores.Piece(index: $0.pieceIndex, splitMs: $0.splitMs, satOut: $0.satOut) },
                postedAverageMs: first.postedAvgSplitMs
            )
        }
    }

    /// Each rower's 500m splits from their own post linked to the workout (NP3): their main piece's
    /// split rows, kept when they posted. Rowers whose post has none (posted before NP3, a manual
    /// entry, an interval photo) aren't in it. Read on its own so nothing else depends on the column.
    static func postedSplits(for workoutId: UUID) async throws -> [UUID: [Int]] {
        nonisolated struct Row: Decodable {
            struct Segment: Decodable {
                let label: SegmentLabel
                let position: Int
                let splits500Ms: [Int]?
                enum CodingKeys: String, CodingKey {
                    case label, position
                    case splits500Ms = "splits_500_ms"
                }
            }
            let userId: UUID
            let segments: [Segment]
            enum CodingKeys: String, CodingKey {
                case segments
                case userId = "user_id"
            }
        }
        let rows: [Row] = try await SupabaseService.shared
            .from("sessions")
            .select("user_id, segments(label, position, splits_500_ms)")
            .eq("workout_id", value: workoutId)
            .execute().value
        var result: [UUID: [Int]] = [:]
        for row in rows where result[row.userId] == nil {
            let pieces = row.segments.filter { $0.label != .warmup && $0.label != .cooldown }.sorted { $0.position < $1.position }
            let main = pieces.first { $0.label == .main } ?? pieces.first
            if let splits = main?.splits500Ms, !splits.isEmpty { result[row.userId] = splits }
        }
        return result
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
            let p_splits_500_ms: [Int]?
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
                // Only sent when there are splits (a scanned test), so typing a score works on a
                // project whether or not the NP3 migration has reached it yet.
                try c.encodeIfPresent(p_splits_500_ms, forKey: .p_splits_500_ms)
            }
            enum Keys: String, CodingKey {
                case p_workout, p_user, p_piece, p_split_ms, p_time_ms, p_distance_m, p_rate, p_sat_out, p_source,
                     p_splits_500_ms
            }
        }
        try await SupabaseService.shared.rpc("save_notepad_score", params: Params(
            p_workout: score.workoutId, p_user: score.userId, p_piece: score.pieceIndex,
            p_split_ms: score.splitMs, p_time_ms: score.timeMs, p_distance_m: score.distanceM,
            p_rate: score.rate, p_sat_out: score.satOut, p_source: score.source.rawValue,
            p_splits_500_ms: score.splits500Ms
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
