//
//  ReviewFieldLabel.swift
//  Rowing Pals
//

import SwiftUI

/// v3 field label on Review session: 12.5 pt, bold, muted.
struct ReviewFieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(Typography.fieldLabel)
            .foregroundStyle(Tokens.Ink.secondary)
    }
}
