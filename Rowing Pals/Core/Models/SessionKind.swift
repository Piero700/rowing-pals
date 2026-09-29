//
//  SessionKind.swift
//  Rowing Pals
//

import Foundation

/// What a session is being posted as: ordinary training, or an attempt at
/// one of the standard tests (the review screen's "Session type" dropdown,
/// docs/design/rowing-pals-redesign-handoff-v2.md §2 Screen 05). Only a test
/// writes a `test_results` row — nothing enters the test rankings without the
/// rower choosing it here.
enum SessionKind: Hashable, Identifiable {
    case training
    case test(StandardTest)

    /// Every choice the dropdown offers: Training, then each standard test.
    static var allCases: [SessionKind] {
        [.training] + StandardTest.all.map { .test($0) }
    }

    var id: String {
        switch self {
        case .training: "training"
        case .test(let test): test.key
        }
    }

    var label: String {
        switch self {
        case .training: "Training"
        case .test(let test): "\(test.label) test"
        }
    }

    var test: StandardTest? {
        if case .test(let test) = self { test } else { nil }
    }

    /// Text for `sessions.workout_label` when the session is a test — the
    /// test's own name replaces the training label, as in the prototype.
    var testLabel: String? { test.map { "\($0.label) test" } }

    /// Why this session can't be posted as this kind, or nil if it can. A
    /// distance test must be exactly its distance ("The distance must match
    /// the selected test", per the prototype); a timed test must be its
    /// duration, within a small tolerance for finish-line rounding.
    func problem(distanceM: Int, timeMs: Int) -> String? {
        guard let test else { return nil }
        if test.accepts(distanceM: distanceM, timeMs: timeMs) { return nil }
        switch test.target {
        case .distance(let target):
            return "A \(test.label) test must be exactly \(target.formattedWithGrouping)m."
        case .duration:
            return "A \(test.label) test must be \(test.label) long."
        }
    }
}
