//
//  SingleScullDrawing.swift
//  Rowing Pals
//

import SwiftUI

/// A single scull on its side, across the width it's given (the rower's Feed, user 2026-10-17),
/// drawn with the same hull, wing riggers, oars at the catch and spoon blades as the bigger boats
/// (decision 86, `SidewaysBoatParts`): the bow ball on the right, the cockpit a little towards the
/// stern, and the sculler's seat filled in. No names or labels: in a single it's just you.
struct SingleScullDrawing: View {
    var body: some View {
        Canvas { context, size in
            let y = size.height / 2
            let left: CGFloat = 3
            let right = size.width - 3
            let length = right - left
            SidewaysBoatParts.drawHull(in: &context, left: left, right: right, y: y)

            // The seat sits a little towards the stern (left), as in a real single.
            let seatX = left + length * 0.46
            let cockpit = length * Tokens.Boat.singleCockpitShare
            SidewaysBoatParts.drawDeck(in: &context, from: seatX - cockpit / 2, to: seatX + cockpit / 2, y: y)
            SidewaysBoatParts.drawOar(in: &context, seatX: seatX, y: y, up: true)
            SidewaysBoatParts.drawOar(in: &context, seatX: seatX, y: y, up: false)

            let r = Tokens.Boat.sidewaysSeatRadius
            context.fill(Path(ellipseIn: CGRect(x: seatX - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Tokens.Accent.brand))
        }
        .frame(height: Tokens.Boat.singleHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A single scull")
    }
}
