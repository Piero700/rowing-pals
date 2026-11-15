//
//  SettingsCheckmark.swift
//  Rowing Pals
//

import SwiftUI

/// The tick on the chosen Settings row (Appearance); it keeps its space when hidden.
struct SettingsCheckmark: View {
    let isOn: Bool

    var body: some View {
        RPIconView(icon: .check, size: Tokens.Icon.small)
            .textStyle(Typography.rowTitle)
            .foregroundStyle(Tokens.Accent.brand)
            .opacity(isOn ? 1 : 0)
            .accessibilityHidden(!isOn)
    }
}
