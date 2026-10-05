//
//  WorkoutService.swift
//  Rowing Pals
//

import Foundation
import PaceEngine
import Supabase

/// Set workouts (decisions 39, 49–51): coaches create and delete them through
/// `create_workout` / `delete_workout`, which check they coach the club and tell everyone it's
/// for; reads go straight to the tables, where the database shows a coach their club's
/// workouts and a rower the ones set for them (docs/migrations/2026-10-05-coaching.sql §5–5b).
enum WorkoutService {
    /// What a coach fills in on New workout.
    struct Draft {
        var title: String
        var date: Date
        var startTime: Date?
        var description: String
        var zone: TrainingZone?
        var testKey: String?
        var pieces: [WorkoutPiece]
        var audience: WorkoutAudience
        var squadIds: Set<UUID>
        var rowerIds: Set<UUID>
    }

    private static let columns = "*, coach_workout_targets(squad_id, user_id)"

    /// Sets the workout; returns its id.
    @discardableResult
    static func create(_ draft: Draft, calendar: Calendar = .current) async throws -> UUID {
        struct Params: Encodable {
            let p_title: String
            let p_date: String
            let p_start_time: String?
            let p_description: String?
            let p_zone: String?
            let p_test_key: String?
            let p_pieces: [WorkoutPiece]
            let p_audience: WorkoutAudience
            let p_squads: [UUID]
            let p_rowers: [UUID]

            // Every key is sent, so an empty choice is null rather than missing.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_title, forKey: .p_title)
                try c.encode(p_date, forKey: .p_date)
                try c.encode(p_start_time, forKey: .p_start_time)
                try c.encode(p_description, forKey: .p_description)
                try c.encode(p_zone, forKey: .p_zone)
                try c.encode(p_test_key, forKey: .p_test_key)
                try c.encode(p_pieces, forKey: .p_pieces)
                try c.encode(p_audience, forKey: .p_audience)
                try c.encode(p_squads, forKey: .p_squads)
                try c.encode(p_rowers, forKey: .p_rowers)
            }
            enum Keys: String, CodingKey {
                case p_title, p_date, p_start_time, p_description, p_zone, p_test_key, p_pieces,
                     p_audience, p_squads, p_rowers
            }
        }
        let time = draft.startTime.map { date -> String in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        }
        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = Params(
            p_title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            p_date: WorkoutRules.dayText(draft.date, calendar: calendar),
            p_start_time: time,
            p_description: description.isEmpty ? nil : description,
            p_zone: draft.testKey == nil ? draft.zone?.rawValue : TrainingZone.an.rawValue,
            p_test_key: draft.testKey,
            p_pieces: draft.pieces,
            p_audience: draft.audience,
            p_squads: draft.audience == .squads ? Array(draft.squadIds) : [],
            p_rowers: draft.audience == .rowers ? Array(draft.rowerIds) : []
        )
        return try await SupabaseService.shared.rpc("create_workout", params: params).execute().value
    }

    static func delete(_ workoutId: UUID) async throws {
        struct Params: Encodable { let p_workout: UUID }
        try await SupabaseService.shared.rpc("delete_workout", params: Params(p_workout: workoutId)).execute()
    }

    // MARK: - The coach's side

    /// Every workout of the club the caller coaches, newest day first.
    static func clubWorkouts() async throws -> [CoachWorkout] {
        let viewer = try await ViewerContext.shared.current()
        guard viewer.isCoach, let clubId = viewer.clubId else { throw CoachingService.CoachingError.notACoach }
        return try await SupabaseService.shared
            .from("coach_workouts").select(columns).eq("club_id", value: clubId)
            .order("workout_date", ascending: false).execute().value
    }

    static func workout(_ id: UUID) async throws -> CoachWorkout {
        try await SupabaseService.shared
            .from("coach_workouts").select(columns).eq("id", value: id).single().execute().value
    }

    /// Who each workout is for: every rowing member it reaches, from `workout_audiences`.
    static func audiences(of workoutIds: [UUID]) async throws -> [UUID: Set<UUID>] {
        guard !workoutIds.isEmpty else { return [:] }
        nonisolated struct Row: Decodable {
            let workoutId: UUID
            let userId: UUID
            enum CodingKeys: String, CodingKey {
                case workoutId = "workout_id"
                case userId = "user_id"
            }
        }
        struct Params: Encodable { let p_workouts: [UUID] }
        let rows: [Row] = try await SupabaseService.shared
            .rpc("workout_audiences", params: Params(p_workouts: workoutIds)).execute().value
        var result: [UUID: Set<UUID>] = [:]
        for row in rows { result[row.workoutId, default: []].insert(row.userId) }
        return result
    }

    /// One session linked to a workout, with its pieces.
    struct LinkedSession {
        let id: UUID
        let userId: UUID
        let workoutId: UUID
        let segments: [WorkoutRules.LinkedSegment]
    }

    /// Every session linked to these workouts.
    static func linkedSessions(to workoutIds: [UUID]) async throws -> [LinkedSession] {
        guard !workoutIds.isEmpty else { return [] }
        nonisolated struct Row: Decodable {
            struct Segment: Decodable {
                let position: Int
                let label: SegmentLabel
                let distanceM: Int
                let timeMs: Int
                let splitMs: Int?
                let rate: Double?
                let repDistanceM: Int?
                enum CodingKeys: String, CodingKey {
                    case position, label, rate
                    case distanceM = "distance_m"
                    case timeMs = "time_ms"
                    case splitMs = "split_ms"
                    case repDistanceM = "rep_distance_m"
                }
            }
            let id: UUID
            let userId: UUID
            let workoutId: UUID
            let sessionDate: String
            let segments: [Segment]
            enum CodingKeys: String, CodingKey {
                case id, segments
                case userId = "user_id"
                case workoutId = "workout_id"
                case sessionDate = "session_date"
            }
        }
        let rows: [Row] = try await SupabaseService.shared
            .from("sessions")
            .select("id, user_id, workout_id, session_date, segments(position, label, distance_m, time_ms, split_ms, rate, rep_distance_m)")
            .in("workout_id", values: workoutIds)
            .execute().value
        return rows.map { row in
            LinkedSession(id: row.id, userId: row.userId, workoutId: row.workoutId, segments: row.segments.map {
                WorkoutRules.LinkedSegment(
                    sessionDate: row.sessionDate, position: $0.position, label: $0.label,
                    distanceM: $0.distanceM, timeMs: $0.timeMs,
                    splitMs: $0.splitMs ?? (($0.distanceM > 0) ? Int(Double($0.timeMs) / (Double($0.distanceM) / 500)) : 0),
                    rate: $0.rate, repDistanceM: $0.repDistanceM
                )
            })
        }
    }

    /// Each rower's status on a workout, from its audience and linked sessions.
    static func statuses(
        for workout: CoachWorkout, audience: Set<UUID>, sessions: [LinkedSession]
    ) -> [UUID: WorkoutStatus] {
        var result: [UUID: WorkoutStatus] = [:]
        for rower in audience {
            let mine = sessions.filter { $0.workoutId == workout.id && $0.userId == rower }
            result[rower] = WorkoutRules.status(
                pieces: workout.pieces, segments: mine.flatMap(\.segments), hasLinkedSession: !mine.isEmpty
            )
        }
        return result
    }

    // MARK: - The rower's side

    /// The workouts set for the signed-in rower between two days (inclusive), earliest first.
    static func mine(from: Date, to: Date, calendar: Calendar = .current) async throws -> [CoachWorkout] {
        struct Params: Encodable { let p_from: String; let p_to: String }
        return try await SupabaseService.shared
            .rpc("my_workouts", params: Params(
                p_from: WorkoutRules.dayText(from, calendar: calendar),
                p_to: WorkoutRules.dayText(to, calendar: calendar)
            ))
            .execute().value
    }

    /// The workouts set for the signed-in rower today, with who set them and the rower's own
    /// target split. Empty for anyone who doesn't row, or before the coaching migration.
    static func today(calendar: Calendar = .current) async -> [TodaysWorkout] {
        guard let viewer = try? await ViewerContext.shared.current(), viewer.isRower, let clubId = viewer.clubId else { return [] }
        struct Params: Encodable { let p_from: String; let p_to: String }
        let day = WorkoutRules.dayText(Date(), calendar: calendar)
        guard let workouts: [CoachWorkout] = try? await SupabaseService.shared
            .rpc("my_workouts", params: Params(p_from: day, p_to: day))
            .select(columns)
            .execute().value, !workouts.isEmpty else { return [] }

        async let namesTask = coachNames(for: workouts)
        async let squadsTask = try? await CoachingService.squads(of: clubId)
        async let predictionTask = try? await PredictionService.predictions(for: [2000])
        let (names, squads, predictions) = await (namesTask, squadsTask, predictionTask)
        let twoK = predictions?[2000].flatMap { PredictionService.isShowable($0) ? $0.predictedSplitSeconds : nil }

        return workouts.map { workout in
            let forWhom: String
            switch workout.audience {
            case .club:
                forWhom = "whole club"
            case .squads:
                let mine = (squads ?? []).filter { workout.squadIds.contains($0.id) && $0.memberIds.contains(viewer.userId) }
                forWhom = mine.isEmpty ? "your squad" : mine.map(\.name).sorted().joined(separator: ", ")
            case .rowers:
                forWhom = "you"
            }
            let coach = workout.createdBy.flatMap { names[$0] }
            let target = workout.pieces.first.flatMap {
                WorkoutRules.targetSplitMs(piece: $0, zone: WorkoutRules.zone(of: workout), twoKSplitSeconds: twoK)
            }
            return TodaysWorkout(
                workout: workout,
                fromText: coach.map { "From \($0) · \(forWhom)" } ?? "For \(forWhom)",
                targetSplitMs: target
            )
        }
    }

    /// Display names of the coaches who set these workouts.
    static func coachNames(for workouts: [CoachWorkout]) async -> [UUID: String] {
        let ids = Array(Set(workouts.compactMap(\.createdBy)))
        guard !ids.isEmpty else { return [:] }
        nonisolated struct Row: Decodable {
            let id: UUID
            let displayName: String
            enum CodingKeys: String, CodingKey {
                case id
                case displayName = "display_name"
            }
        }
        let rows: [Row] = (try? await SupabaseService.shared
            .from("profiles").select("id, display_name").in("id", values: ids).execute().value) ?? []
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.displayName) })
    }
}
