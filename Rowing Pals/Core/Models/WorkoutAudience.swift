//
//  WorkoutAudience.swift
//  Rowing Pals
//

import Foundation

/// Who a set workout is for (decision 39): the whole club, chosen squads, or chosen rowers.
/// Mirrors `coach_workouts.audience`.
nonisolated enum WorkoutAudience: String, Codable, CaseIterable, Identifiable {
    case club
    case squads
    case rowers

    var id: Self { self }

    var label: String {
        switch self {
        case .club: "Whole club"
        case .squads: "Squads"
        case .rowers: "Rowers"
        }
    }
}
