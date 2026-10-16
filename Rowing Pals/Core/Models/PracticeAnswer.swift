//
//  PracticeAnswer.swift
//  Rowing Pals
//

/// A rower's answer to a practice (decision 68): Available or Can't. Stored as `going` / `cant`
/// in `attendance_responses.answer`.
nonisolated enum PracticeAnswer: String, Codable, CaseIterable {
    case going, cant

    var label: String { self == .going ? "Available" : "Can’t" }
}
