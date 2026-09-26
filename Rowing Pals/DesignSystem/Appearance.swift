//
//  Appearance.swift
//  Rowing Pals
//

import SwiftUI

/// Dark or light, chosen in Settings → Appearance (v3). A per-device display preference like
/// `DistanceUnit`, so `@AppStorage`, applied once at the app root. Dark is the primary design,
/// so it's the default.
enum Appearance: String, CaseIterable {
    case dark, light

    static let storageKey = "appearancePreference"

    var colorScheme: ColorScheme {
        switch self {
        case .dark: .dark
        case .light: .light
        }
    }
}
