//
//  WorkoutsText.swift
//  Rowing Pals
//

import Foundation

/// How Coaching writes who a workout is for (CoachWorkouts): "Whole club", "Senior men, Senior
/// women", "Tom Ashworth and 2 more"; a test day adds "· test day".
enum WorkoutsText {
    static func audience(_ workout: CoachWorkout, squads: [UUID: String], names: [UUID: String]) -> String {
        let who: String
        switch workout.audience {
        case .club:
            who = "Whole club"
        case .squads:
            let chosen = workout.squadIds.compactMap { squads[$0] }.sorted()
            who = chosen.isEmpty ? "Squads" : chosen.joined(separator: ", ")
        case .rowers:
            let chosen = workout.rowerIds.compactMap { names[$0] }.sorted()
            switch chosen.count {
            case 0: who = "Rowers"
            case 1...2: who = chosen.joined(separator: " and ")
            default: who = "\(chosen[0]) and \(chosen.count - 1) more"
            }
        }
        return workout.isTestDay ? "\(who) · test day" : who
    }
}
