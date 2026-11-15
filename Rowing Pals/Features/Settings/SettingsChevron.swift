//
//  SettingsChevron.swift
//  Rowing Pals
//

import SwiftUI

/// The chevron at the end of a Settings row that opens something.
struct SettingsChevron: View {
    var body: some View {
        RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
            .textStyle(Typography.pill)
            .foregroundStyle(Tokens.Ink.secondary)
    }
}
