//
//  Appearance.swift
//  Rowing Pals
//

import SwiftUI

/// Dark, light, or the iPhone's own setting, chosen in Settings → Appearance (v4, decision 36).
/// A per-device display preference like `DistanceUnit`, so `@AppStorage`, applied once at the
/// app root. Dark is the primary design, so it's the default.
enum Appearance: String, CaseIterable {
    case dark, light
    /// Match iPhone: follows the system Light / Dark setting.
    case system

    static let storageKey = "appearancePreference"

    /// Nil leaves the choice to iOS.
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: .unspecified
        }
    }

    /// Applies the choice to every window, and so to every sheet in it at once. Set on the
    /// window directly because SwiftUI's `preferredColorScheme(nil)` doesn't hand control back
    /// to iOS once a scheme has been forced: picking Match iPhone after Dark kept the app dark
    /// until it was relaunched.
    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
}
