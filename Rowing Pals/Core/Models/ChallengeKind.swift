//
//  ChallengeKind.swift
//  Rowing Pals
//

import Foundation

/// The three kinds of club challenge (decision 91), all on erg metres on the leaderboards.
nonisolated enum ChallengeKind: String, Codable, CaseIterable, Sendable {
    /// Each rower aims for the same number of metres.
    case target
    /// The club together towards one number.
    case clubTotal = "club_total"
    /// Two or more squads race on metres per rower.
    case squads

    var label: String {
        switch self {
        case .target: "Personal target"
        case .clubTotal: "Club total"
        case .squads: "Squad vs squad"
        }
    }

    /// The line under the kind when choosing one.
    var explanation: String {
        switch self {
        case .target: "Every rower aims for the same metres by the end."
        case .clubTotal: "The club rows towards one total together."
        case .squads: "Squads race each other on metres per rower."
        }
    }
}
