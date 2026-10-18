//
//  SidewaysBoatParts.swift
//  Rowing Pals
//

import SwiftUI

/// The pieces of a boat drawn on its side on the rower's Feed (decision 86, the canvas's draft A),
/// shared by `SidewaysBoatDrawing` and `SingleScullDrawing` so a single and an eight look like the
/// same kind of boat: the hull pointed at both ends with the bow ball on the right, the open deck,
/// and for each oar a wing rigger, the shaft at the catch (swept towards the bow, the handle in
/// across the gunwale) and a squared spoon blade with its face to the stern side.
enum SidewaysBoatParts {
    /// The hull from `left` to `right` about the centre line `y`, its faint keel line and the bow ball.
    static func drawHull(in context: inout GraphicsContext, left: CGFloat, right: CGFloat, y: CGFloat) {
        let hh = Tokens.Boat.sidewaysHullHalfWidth
        let length = right - left
        var hull = Path()
        hull.move(to: CGPoint(x: left, y: y))
        hull.addCurve(to: CGPoint(x: left + length * 0.5, y: y - hh),
                      control1: CGPoint(x: left + length * 0.07, y: y - hh * 0.4),
                      control2: CGPoint(x: left + length * 0.28, y: y - hh))
        hull.addCurve(to: CGPoint(x: right, y: y),
                      control1: CGPoint(x: left + length * 0.72, y: y - hh),
                      control2: CGPoint(x: right - length * 0.07, y: y - hh * 0.4))
        hull.addCurve(to: CGPoint(x: left + length * 0.5, y: y + hh),
                      control1: CGPoint(x: right - length * 0.07, y: y + hh * 0.4),
                      control2: CGPoint(x: left + length * 0.72, y: y + hh))
        hull.addCurve(to: CGPoint(x: left, y: y),
                      control1: CGPoint(x: left + length * 0.28, y: y + hh),
                      control2: CGPoint(x: left + length * 0.07, y: y + hh * 0.4))
        hull.closeSubpath()
        context.fill(hull, with: .color(Tokens.Surface.raised))
        context.fill(hull, with: .color(Tokens.Ink.secondary.opacity(Tokens.Boat.sidewaysHullTint)))
        context.stroke(hull, with: .color(Tokens.Ink.secondary), lineWidth: Tokens.Boat.sidewaysHullLine)

        var keel = Path()
        keel.move(to: CGPoint(x: left + 8, y: y))
        keel.addLine(to: CGPoint(x: right - 8, y: y))
        context.stroke(keel, with: .color(Tokens.Surface.line.opacity(0.6)), lineWidth: Tokens.Boat.sidewaysCentreLine)

        let ball = Tokens.Boat.sidewaysBowBall
        context.fill(Path(ellipseIn: CGRect(x: right - 1.5 - ball, y: y - ball, width: ball * 2, height: ball * 2)),
                     with: .color(Tokens.Ink.secondary))
    }

    /// The open deck where the crew sit, from `low` to `high` along the hull.
    static func drawDeck(in context: inout GraphicsContext, from low: CGFloat, to high: CGFloat, y: CGFloat) {
        let hh = Tokens.Boat.sidewaysHullHalfWidth
        let deck = CGRect(x: low, y: y - hh * 0.55, width: high - low, height: hh * 1.1)
        context.fill(Path(roundedRect: deck, cornerRadius: hh * 0.55), with: .color(Tokens.Surface.raised))
    }

    /// The rigger, oar and blade for the seat at `x`: above the hull (`up`) or below it.
    static func drawOar(in context: inout GraphicsContext, seatX x: CGFloat, y: CGFloat, up: Bool) {
        let side: CGFloat = up ? -1 : 1
        let hh = Tokens.Boat.sidewaysHullHalfWidth
        let edge = y + side * hh * 0.85
        let pin = CGPoint(x: x + Tokens.Boat.sidewaysPinLead, y: y + side * (hh + Tokens.Boat.sidewaysRiggerReach))
        let spread = Tokens.Boat.sidewaysRiggerSpread

        var rigger = Path()
        rigger.move(to: CGPoint(x: pin.x - spread, y: edge))
        rigger.addLine(to: pin)
        rigger.addLine(to: CGPoint(x: pin.x + spread, y: edge))
        rigger.move(to: CGPoint(x: pin.x, y: edge))
        rigger.addLine(to: pin)
        context.stroke(rigger, with: .color(Tokens.Ink.secondary),
                       style: StrokeStyle(lineWidth: Tokens.Boat.sidewaysRiggerLine, lineJoin: .round))

        // At the catch the blade is out towards the bow (right), the handle in towards the stern.
        let angle = Tokens.Boat.sidewaysOarAngle * .pi / 180
        let direction = CGVector(dx: sin(angle), dy: side * cos(angle))
        let blade = CGPoint(x: pin.x + direction.dx * Tokens.Boat.sidewaysOarOutboard,
                            y: pin.y + direction.dy * Tokens.Boat.sidewaysOarOutboard)
        let handle = CGPoint(x: pin.x - direction.dx * Tokens.Boat.sidewaysOarInboard,
                             y: pin.y - direction.dy * Tokens.Boat.sidewaysOarInboard)
        var shaft = Path()
        shaft.move(to: handle)
        shaft.addLine(to: blade)
        context.stroke(shaft, with: .color(Tokens.Ink.primary),
                       style: StrokeStyle(lineWidth: Tokens.Boat.sidewaysOarLine, lineCap: .round))
        let r = Tokens.Boat.sidewaysPinRadius
        context.fill(Path(ellipseIn: CGRect(x: pin.x - r, y: pin.y - r, width: r * 2, height: r * 2)),
                     with: .color(Tokens.Ink.secondary))

        drawSpoon(in: &context, from: blade, along: direction)
    }

    /// A squared spoon blade from the neck along the shaft's direction, its face to the stern side.
    private static func drawSpoon(in context: inout GraphicsContext, from neck: CGPoint, along direction: CGVector) {
        let length = Tokens.Boat.sidewaysBladeLength
        let width = Tokens.Boat.sidewaysBladeWidth
        // The normal pointing to the stern (left), where the face is.
        var normal = CGVector(dx: -direction.dy, dy: direction.dx)
        if normal.dx > 0 { normal = CGVector(dx: -normal.dx, dy: -normal.dy) }
        func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(x: neck.x + direction.dx * length * along + normal.dx * across,
                    y: neck.y + direction.dy * length * along + normal.dy * across)
        }
        // The face widens from the neck to its fullest just past halfway, then squares off at the tip.
        let face: [(CGFloat, CGFloat)] = [(0, 0.18), (0.18, 0.78), (0.55, 1), (0.88, 0.92), (1, 0.45)]
        var spoon = Path()
        spoon.move(to: point(face[0].0, width * face[0].1 * 0.85))
        for (along, share) in face.dropFirst() {
            spoon.addLine(to: point(along, width * share * 0.85))
        }
        for along in [CGFloat(1), 0.5, 0] {
            spoon.addLine(to: point(along, -width * 0.22))
        }
        spoon.closeSubpath()
        context.fill(spoon, with: .color(Tokens.Ink.primary.opacity(0.9)))
        context.stroke(spoon, with: .color(Tokens.Ink.primary),
                       style: StrokeStyle(lineWidth: Tokens.Boat.sidewaysBladeLine, lineJoin: .round))
    }
}
