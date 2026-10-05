//
//  TrainingZone.swift
//  Rowing Pals
//

import Foundation

/// The training zone a session's main piece was rowed in (decision 31). It replaces the old
/// "Main workout label" (UT2 / UT1 / Threshold / Intervals / Test / Recovery): one choice that
/// is both the badge on the main split ("UT2 · Main workout") and the intensity tag the Pace
/// Engine predicts from. Stored in `sessions.zone`, and as the badge in `sessions.workout_label`
/// unless the session is a test (docs/migrations/2026-10-05-pace-engine-inputs.sql).
enum TrainingZone: String, CaseIterable, Identifiable, Codable {
    case ut2 = "UT2"
    case ut1 = "UT1"
    case at = "AT"
    case tr = "TR"
    case an = "AN"

    var id: String { rawValue }

    /// What the zone means, shown beside its short name when choosing.
    var meaning: String {
        switch self {
        case .ut2: "Steady state"
        case .ut1: "Harder steady state"
        case .at: "Threshold"
        case .tr: "Race pace"
        case .an: "All-out"
        }
    }

    /// "AT · Threshold" — the picker's wording.
    var title: String { "\(rawValue) · \(meaning)" }
}
