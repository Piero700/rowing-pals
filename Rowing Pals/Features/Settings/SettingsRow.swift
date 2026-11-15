//
//  SettingsRow.swift
//  Rowing Pals
//

import SwiftUI

/// A Settings row that is itself a control (a whole-row button) when `action` is given.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var titleColor: Color = Tokens.Ink.primary
    @ViewBuilder var trailing: () -> Trailing
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                SettingsRowContent(title: title, subtitle: subtitle, titleColor: titleColor, trailing: trailing)
            }
            .buttonStyle(IconPressStyle())
        } else {
            SettingsRowContent(title: title, subtitle: subtitle, titleColor: titleColor, trailing: trailing)
        }
    }
}
