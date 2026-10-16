//
//  RosterSort.swift
//  Rowing Pals
//

import Foundation

/// The orders Coaching's Rowers list offers (CoachSortSheet; decision 62 adds On target, best and
/// worst by 2k, and Attendance, user 2026-10-14).
nonisolated enum RosterSort: String, CaseIterable, Identifiable {
    /// Furthest behind their pro-rata weekly target first.
    case behindTarget
    /// On track first, furthest through their weekly target first.
    case onTarget
    /// Fastest 2k first: their PB, or the Pace Engine's prediction without one.
    case bestFirst
    /// Slowest 2k first.
    case worstFirst
    /// Highest share of set workouts posted for and practices attended first.
    case attendance
    /// Longest since their last session first.
    case notLogged
    case name

    var id: Self { self }

    var label: String {
        switch self {
        case .behindTarget: "Behind target"
        case .onTarget: "On target"
        case .bestFirst: "Best to worst"
        case .worstFirst: "Worst to best"
        case .attendance: "Attendance"
        case .notLogged: "Not logged"
        case .name: "Name"
        }
    }

    /// The line under each choice on the sheet.
    var detail: String {
        switch self {
        case .behindTarget: "Furthest behind this week’s target first"
        case .onTarget: "On track first, furthest through their target first"
        case .bestFirst: "Fastest 2k first: PB, or predicted without one"
        case .worstFirst: "Slowest 2k first: PB, or predicted without one"
        case .attendance: "Most workouts and practices attended first"
        case .notLogged: "Longest since their last session first"
        case .name: "A to Z"
        }
    }
}
