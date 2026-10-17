//
//  BoatEndLabel.swift
//  Rowing Pals
//

import SwiftUI

/// "Stern" or "Bow", above and below a drawn boat.
struct BoatEndLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(Typography.tag)
            .foregroundStyle(Tokens.Ink.secondary)
            .frame(height: Tokens.Boat.endLabelHeight)
    }
}
