//
//  InsetCorner.swift
//  Rowing Pals
//

import SwiftUI

/// Which corner of a full-bleed dual-camera photo the smaller inset preview
/// sits in. Genuinely user-configurable per the redesign handoff (§3 "Dual-
/// camera with a 4-corner, user-configurable inset") — not a fixed corner —
/// and independent of any "swap cameras" control, which flips *which*
/// camera feed is main vs inset rather than *where* the inset sits.
///
/// Designed to be reused everywhere a dual-camera composite appears: the
/// capture screen first (this task), then separately the feed card and the
/// workout-hero detail once those land — hence living in `DesignSystem`
/// rather than `Features/Capture`.
///
/// A per-device display preference, same reasoning as `DistanceUnit` and
/// `PaceDisplay` — cosmetic, no reason to sync across a user's devices, so
/// `@AppStorage` rather than a `profiles` column.
enum InsetCorner: String, CaseIterable, Identifiable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    static let storageKey = "insetCornerPreference"

    /// Matches the capture screen's current single fixed position, so
    /// turning this feature on doesn't move anyone's inset on first launch.
    static let defaultCorner: InsetCorner = .topTrailing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topLeading: "Top left"
        case .topTrailing: "Top right"
        case .bottomLeading: "Bottom left"
        case .bottomTrailing: "Bottom right"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }

    var isTop: Bool { self == .topLeading || self == .topTrailing }

    /// Reads the current preference straight from `UserDefaults` — for
    /// `@Observable` view models, which can't hold `@AppStorage` directly.
    /// Deliberately not cached anywhere: the preference can change while a
    /// view model is still alive, so every call re-reads it rather than
    /// risking a stale value.
    static var current: InsetCorner {
        UserDefaults.standard.string(forKey: storageKey).flatMap(InsetCorner.init(rawValue:)) ?? defaultCorner
    }
}
