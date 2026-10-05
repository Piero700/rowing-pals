//
//  RosterSort.swift
//  Rowing Pals
//

import Foundation

/// How Coaching's Rowers list is ordered (CoachSortSheet). Attendance joins with Phase 3.
nonisolated enum RosterSort: String, CaseIterable, Identifiable {
    /// Furthest behind their pro-rata weekly target first.
    case behindTarget
    /// Longest since their last session first.
    case notLogged
    case name

    var id: Self { self }

    var label: String {
        switch self {
        case .behindTarget: "Behind target"
        case .notLogged: "Not logged"
        case .name: "Name"
        }
    }
}
