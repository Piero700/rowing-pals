//
//  Label+RPIcon.swift
//  Rowing Pals
//

import SwiftUI

extension Label where Title == Text, Icon == RPIconView {
    /// A label with one of the app's icons (decision 80) in place of an SF Symbol.
    init(_ title: String, icon: RPIcon, size: CGFloat = Tokens.Icon.regular) {
        self.init { Text(title) } icon: { RPIconView(icon: icon, size: size) }
    }
}
