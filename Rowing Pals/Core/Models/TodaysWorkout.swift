//
//  TodaysWorkout.swift
//  Rowing Pals
//

import Foundation

/// A workout set for the signed-in rower today, ready for the Feed card and the Log screen
/// (RowerFeedCoaching, RowerLogCoaching): who set it, who it's for, and the rower's own target
/// split (decision 51).
nonisolated struct TodaysWorkout: Identifiable, Equatable {
    let workout: CoachWorkout
    /// "From Sarah Lin · whole club".
    let fromText: String
    /// The split to hold on the first piece, the coach's or the rower's own; nil without either.
    let targetSplitMs: Int?
    var id: UUID { workout.id }

    var rateText: String? { WorkoutRules.rateText(workout.pieces) }
    var piecesText: String? { WorkoutRules.piecesSummary(workout.pieces) }
    var zoneText: String { workout.isTestDay ? "Test" : (workout.zone ?? "UT2") }
}
