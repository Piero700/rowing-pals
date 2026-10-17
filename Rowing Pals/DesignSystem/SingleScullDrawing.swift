//
//  SingleScullDrawing.swift
//  Rowing Pals
//

import SwiftUI

/// A single scull on its side, across the width it's given (the rower's Feed, user 2026-10-17):
/// the hull pointed at both ends with the bow ball on the right, the cockpit, a wing rigger and an
/// oar with its spoon blade each side, and the sculler's seat filled in. No names or labels: in a
/// single it's just you.
struct SingleScullDrawing: View {
    var body: some View {
        Canvas { context, size in
            let y = size.height / 2
            let hw = Tokens.Boat.singleHullHalfWidth
            let left: CGFloat = 4
            let right = size.width - 4
            let length = right - left

            var hull = Path()
            hull.move(to: CGPoint(x: left, y: y))
            hull.addCurve(to: CGPoint(x: left + length * 0.5, y: y - hw),
                          control1: CGPoint(x: left + length * 0.07, y: y - hw * 0.4),
                          control2: CGPoint(x: left + length * 0.28, y: y - hw))
            hull.addCurve(to: CGPoint(x: right, y: y),
                          control1: CGPoint(x: left + length * 0.72, y: y - hw),
                          control2: CGPoint(x: right - length * 0.07, y: y - hw * 0.4))
            hull.addCurve(to: CGPoint(x: left + length * 0.5, y: y + hw),
                          control1: CGPoint(x: right - length * 0.07, y: y + hw * 0.4),
                          control2: CGPoint(x: left + length * 0.72, y: y + hw))
            hull.addCurve(to: CGPoint(x: left, y: y),
                          control1: CGPoint(x: left + length * 0.28, y: y + hw),
                          control2: CGPoint(x: left + length * 0.07, y: y + hw * 0.4))
            hull.closeSubpath()
            context.fill(hull, with: .color(Tokens.Surface.raised))
            context.stroke(hull, with: .color(Tokens.Surface.line), lineWidth: Tokens.Boat.lineWidth * 0.9)

            // The seat sits a little towards the stern (left), as in a real single.
            let seatX = left + length * 0.46
            let cockpit = CGRect(x: seatX - length * 0.12, y: y - hw * 0.62, width: length * 0.24, height: hw * 1.24)
            context.fill(Path(roundedRect: cockpit, cornerRadius: hw * 0.6), with: .color(Tokens.Base.ground))
            let ball = Tokens.Boat.small.bowBall + 0.8
            context.fill(Path(ellipseIn: CGRect(x: right - 1 - ball, y: y - ball, width: ball * 2, height: ball * 2)),
                         with: .color(Tokens.Ink.secondary))

            for direction in [CGFloat(-1), 1] {
                let edge = y + direction * hw * 0.9
                let pin = y + direction * (hw + Tokens.Boat.singleRiggerReach)
                var wing = Path()
                wing.move(to: CGPoint(x: seatX - 10, y: edge))
                wing.addLine(to: CGPoint(x: seatX, y: pin))
                wing.addLine(to: CGPoint(x: seatX + 10, y: edge))
                context.stroke(wing, with: .color(Tokens.Ink.secondary),
                               style: StrokeStyle(lineWidth: Tokens.Boat.large.lineWidth, lineJoin: .round))
                let oarEnd = pin + direction * Tokens.Boat.singleOarLength
                var oar = Path()
                oar.move(to: CGPoint(x: seatX, y: pin))
                oar.addLine(to: CGPoint(x: seatX, y: oarEnd))
                context.stroke(oar, with: .color(Tokens.Ink.primary),
                               style: StrokeStyle(lineWidth: Tokens.Boat.large.lineWidth + 0.3, lineCap: .round))
                let bladeCentre = oarEnd + direction * Tokens.Boat.singleBladeLength / 2
                let blade = CGRect(x: seatX - Tokens.Boat.singleBladeDepth / 2, y: bladeCentre - Tokens.Boat.singleBladeLength / 2,
                                   width: Tokens.Boat.singleBladeDepth, height: Tokens.Boat.singleBladeLength)
                context.fill(Path(ellipseIn: blade), with: .color(Tokens.Ink.primary.opacity(0.85)))
            }

            let r = Tokens.Boat.singleSeatRadius
            context.fill(Path(ellipseIn: CGRect(x: seatX - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Tokens.Accent.brand))
        }
        .frame(height: Tokens.Boat.singleHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A single scull")
    }
}
