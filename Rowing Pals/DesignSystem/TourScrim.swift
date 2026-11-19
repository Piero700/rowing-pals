//
//  TourScrim.swift
//  Rowing Pals
//

import SwiftUI

/// The tour's dimmed screen, with a rounded hole round the control a card points at. It takes every
/// tap, the hole's included: only the card's buttons move the tour on.
struct TourScrim: View {
    let hole: CGRect?

    var body: some View {
        Path { path in
            path.addRect(CGRect(x: -2000, y: -2000, width: 6000, height: 6000))
            if let hole {
                path.addRoundedRect(in: hole, cornerSize: CGSize(width: hole.height / 2, height: hole.height / 2),
                                    style: .continuous)
            }
        }
        .fill(Tokens.Tour.scrim, style: FillStyle(eoFill: true))
        .contentShape(Rectangle())
        .onTapGesture {}
        .accessibilityHidden(true)
    }
}
