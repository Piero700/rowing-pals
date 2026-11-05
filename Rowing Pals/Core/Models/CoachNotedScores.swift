//
//  CoachNotedScores.swift
//  Rowing Pals
//

import Foundation

/// The scores a rower's coach noted for them on one workout's notepad (RowerCoachScores, decision
/// 96, NP4), from `my_notepad_scores`: only the rower's own scores, never anyone else's or the
/// page's text, tables and Notes. Shown on their Feed for a few days after the workout.
nonisolated struct CoachNotedScores: Identifiable, Equatable {
    struct Piece: Equatable {
        let index: Int
        /// Nil when sat out.
        let splitMs: Int?
        let satOut: Bool
    }

    let workoutId: UUID
    let title: String
    /// "yyyy-MM-dd", as `coach_workouts.workout_date`.
    let workoutDate: String
    let pieces: [WorkoutPiece]
    let testKey: String?
    let coachName: String?
    let clubName: String?
    /// Their place in erg order (1 = first erg), when the coach set one.
    let erg: Int?
    /// Only the pieces the coach noted, in order.
    let scores: [Piece]
    /// Their own post's average, when they posted the workout.
    let postedAverageMs: Int?

    var id: UUID { workoutId }
    var hasPosted: Bool { postedAverageMs != nil }
}
