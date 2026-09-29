//
//  WorkoutLabel.swift
//  Rowing Pals
//

import Foundation

/// The kind of training a session's main piece was — the "Main workout
/// label" dropdown on the review screen (docs/design/
/// rowing-pals-redesign-handoff-v2.md §2 Screen 05). Shown as the badge on
/// the main split, e.g. "UT2 · Main workout". Stored as its display text in
/// `sessions.workout_label`. A test session stores its test label instead
/// (see `SessionKind.workoutLabel`).
enum WorkoutLabel: String, CaseIterable, Identifiable {
    case ut2 = "UT2"
    case ut1 = "UT1"
    case threshold = "Threshold"
    case intervals = "Intervals"
    case test = "Test"
    case recovery = "Recovery"

    var id: String { rawValue }
}
