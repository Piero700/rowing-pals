//
//  WorkoutAttendance.swift
//  Rowing Pals
//

import Foundation

/// How many of the workouts set for a rower they posted for (decision 62): the canvas's
/// "attendance", from set workouts until Phase 3 adds practices to it. A workout counts once its
/// day is over, or on the day once it's been posted for; one with nothing posted after its day is
/// an absence (decision 57).
nonisolated struct WorkoutAttendance: Equatable {
    var attended: Int
    var set: Int

    static let zero = WorkoutAttendance(attended: 0, set: 0)

    /// 0–100, rounded; nil with nothing set yet.
    var percent: Int? {
        guard set > 0 else { return nil }
        return Int((Double(attended) / Double(set) * 100).rounded())
    }

    /// "84% attendance", or nil with nothing set yet.
    var text: String? { percent.map { "\($0)% attendance" } }

    /// Everyone's together, for the list's summary figure.
    static func total(_ items: some Sequence<WorkoutAttendance>) -> WorkoutAttendance {
        items.reduce(.zero) { WorkoutAttendance(attended: $0.attended + $1.attended, set: $0.set + $1.set) }
    }
}
