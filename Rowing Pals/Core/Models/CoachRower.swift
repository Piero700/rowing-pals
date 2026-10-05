//
//  CoachRower.swift
//  Rowing Pals
//

import Foundation
import PaceEngine

/// One rower on Coaching's Rowers list: this week against their target, their 2k, the Pace
/// Engine's 2k prediction and anything to look at (decisions 34, 39). Coach-only accounts are
/// never on it; rowing coaches are, marked "Coach".
nonisolated struct CoachRower: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let avatarPath: String?
    let category: RowerCategory
    let gender: RowerGender?
    let isPrivate: Bool
    let isCoach: Bool
    /// The squads they're in, by name, alphabetical.
    let squadNames: [String]
    let squadIds: Set<UUID>
    /// Every session this week (Monday on), leaderboard or not: any session counts towards the
    /// weekly target (decision 36).
    let weekMetres: Int
    let weekSessions: Int
    let weeklyTargetM: Int
    /// Days since their last session; nil when there's none in the window read.
    let daysSinceSession: Int?
    /// Best 2k, milliseconds.
    let twoKBestMs: Int?
    let prediction: Prediction?
    let flags: [CoachFlag]
    /// How far behind the pro-rata target, in metres; 0 when on track.
    let shortfallM: Int

    var isBehindTarget: Bool { shortfallM > 0 }
}
