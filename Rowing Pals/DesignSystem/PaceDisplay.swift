//
//  PaceDisplay.swift
//  Rowing Pals
//

import Foundation

/// A per-device display preference, same reasoning as `DistanceUnit`.
/// `split_ms` stays the stored/canonical value everywhere (CLAUDE.md's
/// "split — pace per 500 metres... Never 'pace'" domain-vocabulary rule
/// is about the stored quantity's name, not what the display layer is
/// allowed to derive from it) — this only changes what's rendered.
enum PaceDisplay: String, CaseIterable {
    case split, watts

    static let storageKey = "paceDisplayPreference"

    var label: String {
        switch self {
        case .split: "Split"
        case .watts: "Watts"
        }
    }

    /// Reads the current preference straight from `UserDefaults` — for
    /// `@Observable` view models, which can't hold `@AppStorage` directly.
    /// Deliberately not cached anywhere: the preference can change from
    /// Settings while a view model is still alive, so every call re-reads
    /// it rather than risking a stale value.
    static var current: PaceDisplay {
        UserDefaults.standard.string(forKey: storageKey).flatMap(PaceDisplay.init(rawValue:)) ?? .split
    }
}

extension Int {
    /// This split (milliseconds per 500m) formatted per the user's stored
    /// display preference — `"2:01.6"` or `"186W"`.
    ///
    /// Watts uses Concept2's own published conversion — `watts = 2.80 /
    /// pace³`, pace in seconds per metre — the same formula every rower
    /// who owns a PM5 already reads off their own monitor, not an
    /// invented approximation.
    func formattedPace(display: PaceDisplay) -> String {
        switch display {
        case .split:
            return formattedDurationMs
        case .watts:
            guard self > 0 else { return "—" }
            let paceSecondsPerMetre = (Double(self) / 1000) / 500
            let watts = 2.80 / pow(paceSecondsPerMetre, 3)
            return "\(Int(watts.rounded()))W"
        }
    }
}
