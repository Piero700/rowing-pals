//
//  WorkoutStatus.swift
//  Rowing Pals
//

import Foundation

/// Where a rower is with a set workout (decision 49): done (the whole workout, in sessions
/// linked to it), partly (a linked session that didn't complete all of it), not yet (no linked
/// session, and the day isn't over) or absent (the day passed with nothing linked — decision 57).
nonisolated enum WorkoutStatus: Equatable, Hashable {
    case done
    /// `completed` of `total` reps.
    case partly(completed: Int, total: Int)
    case notYet
    case absent

    var isDone: Bool { self == .done }
}
