//
//  CaptureFlipLabel.swift
//  Rowing Pals
//

import SwiftUI

/// The round 48 pt glass flip button on the Log camera screens.
struct CaptureFlipLabel: View {
    var body: some View {
        RPIconView(icon: .flipCamera)
            .textStyle(Typography.cardTitle)
            .foregroundStyle(Tokens.Ink.primary)
            .frame(width: 48, height: 48)
            .glassSurface(in: Circle())
            .contentShape(Circle())
    }
}
