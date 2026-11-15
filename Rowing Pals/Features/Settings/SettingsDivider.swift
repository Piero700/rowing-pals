//
//  SettingsDivider.swift
//  Rowing Pals
//

import SwiftUI

/// The full-width hairline between two Settings rows.
struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(Tokens.Surface.line).frame(height: Tokens.Grouped.hairline)
    }
}
