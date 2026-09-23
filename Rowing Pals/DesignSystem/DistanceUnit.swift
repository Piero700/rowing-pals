//
//  DistanceUnit.swift
//  Rowing Pals
//

import Foundation

/// A per-device display preference, not a `profiles` column — like the
/// prototype's own Appearance (dark/light) setting, this is cosmetic and
/// has no reason to sync across a user's devices, so it's `@AppStorage`
/// rather than a Supabase-backed field.
///
/// Storage stays metres everywhere (`distance_m` columns, CLAUDE.md's own
/// "All distances stored as whole metres" rule) — this only changes what
/// the display layer renders.
///
/// Scope (docs/design/v2-decisions.md #3): this preference applies to the
/// **Volume leaderboard totals only**, where weekly/monthly/yearly sums
/// get large. Every other distance — posts, sessions, profile, PBs, test
/// results — always shows in metres via `formattedMetres`.
enum DistanceUnit: String, CaseIterable {
    case metres, kilometres

    static let storageKey = "distanceUnitPreference"

    var label: String {
        switch self {
        case .metres: "Metres"
        case .kilometres: "Kilometres"
        }
    }

    /// Reads the current preference straight from `UserDefaults` — for
    /// `@Observable` view models, which can't hold `@AppStorage` directly.
    /// Deliberately not cached anywhere: the preference can change from
    /// Settings while a view model is still alive, so every call re-reads
    /// it rather than risking a stale value.
    static var current: DistanceUnit {
        UserDefaults.standard.string(forKey: storageKey).flatMap(DistanceUnit.init(rawValue:)) ?? .metres
    }
}

extension Int {
    /// This distance (whole metres) always in metres — `"16,000m"`. Used
    /// everywhere except the Volume leaderboard, which honours the
    /// user's `DistanceUnit` preference via `formattedDistance(unit:)`.
    var formattedMetres: String { "\(formattedWithGrouping)m" }

    /// This distance (whole metres) formatted per the user's stored unit
    /// preference — `"16,000m"` or `"16.0km"`. A fixed one decimal place
    /// in km, not a trimmed variable-precision number: CLAUDE.md's tabular-
    /// numerals rule exists so numbers stay comparable at a glance, and a
    /// column of "4.0km" / "16.2km" holds that; "4km" / "16.2km" doesn't.
    func formattedDistance(unit: DistanceUnit) -> String {
        switch unit {
        case .metres:
            return formattedMetres
        case .kilometres:
            let km = Double(self) / 1000
            return String(format: "%.1fkm", km)
        }
    }
}
