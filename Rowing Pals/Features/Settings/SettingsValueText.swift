//
//  SettingsValueText.swift
//  Rowing Pals
//

import SwiftUI

/// A Settings row's current value, before its chevron ("Private", "Verified").
struct SettingsValueText: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(Typography.detail)
            .foregroundStyle(Tokens.Ink.secondary)
    }
}
