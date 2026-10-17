//
//  BoatDrawing.swift
//  Rowing Pals
//

import SwiftUI

/// A boat drawn as a racing shell from above (decisions 67, 74; CoachBoats, CoachBoatEdit,
/// RowerBoat): long and narrow, pointed at both ends, decks fore and aft with the cockpit between,
/// the bow ball, a wing rigger and an oar with a spoon blade at every seat (both sides in a
/// sculling boat), the seat marks S · 3 · 2 · B and the cox's square at the stern. Stern at the top
/// unless the viewer chose bow at the top in Settings; with the stern at the top stroke side is on
/// the right. The small drawing writes first names beside the seats; the large one leaves room for
/// the crewing screen's own buttons.
struct BoatDrawing: View {
    let setup: BoatSetup
    var orientation: BoatOrientation = .sternAtTop
    var metrics: Tokens.Boat.Metrics = Tokens.Boat.small
    /// First names by seat, for the small drawing.
    var names: [Int: String] = [:]
    /// The viewer's own seat, filled in brand.
    var highlightedSeat: Int?
    /// The seat being chosen for, dashed.
    var selectedSeat: Int?
    /// Seats with nobody in them yet.
    var emptySeats: Set<Int> = []

    var body: some View {
        let layout = Layout(type: setup.type, metrics: metrics, orientation: orientation)
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in draw(in: &context, layout: layout) }
            ForEach(BoatRules.seats(setup.type), id: \.self) { seat in
                if let name = names[seat] {
                    nameLabel(name, seat: seat, layout: layout)
                }
            }
        }
        .frame(width: metrics.width, height: layout.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Layout

    /// Where everything sits, shared with the crewing screen so its buttons line up.
    struct Layout {
        let type: BoatType
        let metrics: Tokens.Boat.Metrics
        let orientation: BoatOrientation

        var centreX: CGFloat { metrics.width / 2 }

        /// Each seat's centre from the top, in drawing order.
        var seatYs: [Int: CGFloat] {
            let order = BoatRules.seatsTopToBottom(type, orientation: orientation)
            var ys: [Int: CGFloat] = [:]
            var y = metrics.firstSeat
            for (index, seat) in order.enumerated() {
                ys[seat] = y
                if index + 1 < order.count {
                    let next = order[index + 1]
                    y += (seat == 0 || next == 0) ? metrics.coxStep : metrics.seatSpacing
                }
            }
            return ys
        }

        func seatY(_ seat: Int) -> CGFloat { seatYs[seat] ?? 0 }

        var height: CGFloat { (seatYs.values.max() ?? metrics.firstSeat) + metrics.tail }

        /// From the hull's centre line to past the blade: where names start.
        var reach: CGFloat {
            metrics.hullHalfWidth + metrics.riggerReach + metrics.oarLength + metrics.bladeLength + metrics.nameGap
        }

        /// The pin a seat's oar turns on, on the right or left.
        func pinX(right: Bool) -> CGFloat {
            centreX + (right ? 1 : -1) * (metrics.hullHalfWidth + metrics.riggerReach)
        }
    }

    private func draw(in context: inout GraphicsContext, layout: Layout) {
        let m = metrics
        let x = layout.centreX
        let hw = m.hullHalfWidth
        let top: CGFloat = 3
        let bottom = layout.height - 3
        let length = bottom - top

        // The hull: pointed at both ends, widest amidships.
        var hull = Path()
        hull.move(to: CGPoint(x: x, y: top))
        hull.addCurve(to: CGPoint(x: x + hw, y: top + length * 0.5),
                      control1: CGPoint(x: x + hw * 0.4, y: top + length * 0.07),
                      control2: CGPoint(x: x + hw, y: top + length * 0.28))
        hull.addCurve(to: CGPoint(x: x, y: bottom),
                      control1: CGPoint(x: x + hw, y: top + length * 0.72),
                      control2: CGPoint(x: x + hw * 0.4, y: bottom - length * 0.07))
        hull.addCurve(to: CGPoint(x: x - hw, y: top + length * 0.5),
                      control1: CGPoint(x: x - hw * 0.4, y: bottom - length * 0.07),
                      control2: CGPoint(x: x - hw, y: top + length * 0.72))
        hull.addCurve(to: CGPoint(x: x, y: top),
                      control1: CGPoint(x: x - hw, y: top + length * 0.28),
                      control2: CGPoint(x: x - hw * 0.4, y: top + length * 0.07))
        hull.closeSubpath()
        context.fill(hull, with: .color(Tokens.Surface.raised))
        context.stroke(hull, with: .color(Tokens.Surface.line), lineWidth: Tokens.Boat.lineWidth * 0.9)

        // The cockpit between the decks.
        let ys = layout.seatYs.values
        let cockpitTop = (ys.min() ?? top) - m.seatSpacing * 0.42
        let cockpitBottom = (ys.max() ?? bottom) + m.seatSpacing * 0.42
        let cockpit = CGRect(x: x - hw * 0.62, y: cockpitTop, width: hw * 1.24, height: cockpitBottom - cockpitTop)
        context.fill(Path(roundedRect: cockpit, cornerRadius: hw * 0.6), with: .color(Tokens.Base.ground))

        // The bow ball.
        let bowY = orientation == .sternAtTop ? bottom - 1.5 : top + 1.5
        context.fill(Path(ellipseIn: CGRect(x: x - m.bowBall, y: bowY - m.bowBall, width: m.bowBall * 2, height: m.bowBall * 2)),
                     with: .color(Tokens.Ink.secondary))

        for seat in 1...setup.type.rowers {
            let y = layout.seatY(seat)
            if setup.type.isSculling {
                drawRigger(in: &context, layout: layout, y: y, right: true)
                drawRigger(in: &context, layout: layout, y: y, right: false)
            } else {
                drawRigger(in: &context, layout: layout, y: y,
                           right: BoatRules.isOnRight(seat: seat, setup: setup, orientation: orientation))
            }
        }
        for seat in BoatRules.seats(setup.type) {
            drawSeat(in: &context, seat: seat, centre: CGPoint(x: x, y: layout.seatY(seat)))
        }
    }

    /// A wing rigger from the hull out to its pin, the oar beyond it and the spoon blade.
    private func drawRigger(in context: inout GraphicsContext, layout: Layout, y: CGFloat, right: Bool) {
        let m = metrics
        let direction: CGFloat = right ? 1 : -1
        let edge = layout.centreX + direction * m.hullHalfWidth * 0.9
        let pin = layout.pinX(right: right)
        var wing = Path()
        wing.move(to: CGPoint(x: edge, y: y - m.riggerSpread))
        wing.addLine(to: CGPoint(x: pin, y: y))
        wing.addLine(to: CGPoint(x: edge, y: y + m.riggerSpread))
        context.stroke(wing, with: .color(Tokens.Ink.secondary), style: StrokeStyle(lineWidth: m.lineWidth, lineJoin: .round))
        let oarEnd = pin + direction * m.oarLength
        var oar = Path()
        oar.move(to: CGPoint(x: pin, y: y))
        oar.addLine(to: CGPoint(x: oarEnd, y: y))
        context.stroke(oar, with: .color(Tokens.Ink.primary), style: StrokeStyle(lineWidth: m.lineWidth + 0.3, lineCap: .round))
        let bladeCentre = oarEnd + direction * m.bladeLength / 2
        let blade = CGRect(x: bladeCentre - m.bladeLength / 2, y: y - m.bladeDepth / 2, width: m.bladeLength, height: m.bladeDepth)
        context.fill(Path(ellipseIn: blade), with: .color(Tokens.Ink.primary.opacity(0.85)))
    }

    private func drawSeat(in context: inout GraphicsContext, seat: Int, centre: CGPoint) {
        let r = metrics.seatRadius
        let isMine = seat == highlightedSeat
        let isSelected = seat == selectedSeat
        let isEmpty = emptySeats.contains(seat)
        let shape: Path
        if seat == 0 {
            let size = r * 1.7
            shape = Path(roundedRect: CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size), cornerRadius: size / 3)
        } else {
            shape = Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
        }
        if isMine {
            context.fill(shape, with: .color(Tokens.Accent.brand))
        } else if isSelected {
            context.fill(shape, with: .color(Tokens.Accent.brandSoft))
            context.stroke(shape, with: .color(Tokens.Accent.brand),
                           style: StrokeStyle(lineWidth: Tokens.Boat.selectedLineWidth, dash: Tokens.Boat.dash))
        } else {
            context.fill(shape, with: .color(Tokens.Surface.card))
            context.stroke(shape, with: .color(isEmpty ? Tokens.Ink.secondary : Tokens.Ink.primary),
                           style: StrokeStyle(lineWidth: Tokens.Boat.lineWidth, dash: isEmpty ? Tokens.Boat.dash : []))
        }
        let ink: Color = isMine ? Tokens.Ink.onBrand : (isSelected ? Tokens.Accent.brand : (isEmpty ? Tokens.Ink.secondary : Tokens.Ink.primary))
        let mark = Text(BoatRules.seatMark(seat, type: setup.type))
            .font(.system(size: metrics.markFont, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(ink)
        context.draw(mark, at: centre)
    }

    private func nameLabel(_ name: String, seat: Int, layout: Layout) -> some View {
        let right = BoatRules.isOnRight(seat: seat, setup: setup, orientation: orientation)
        let isMine = seat == highlightedSeat
        return Text(name)
            .textStyle(Typography.chip)
            .fontWeight(isMine ? .bold : .semibold)
            .foregroundStyle(isMine ? Tokens.Accent.brand : Tokens.Ink.primary)
            .lineLimit(1)
            .frame(width: metrics.nameWidth, alignment: right ? .leading : .trailing)
            .position(x: right ? layout.centreX + layout.reach + metrics.nameWidth / 2
                               : layout.centreX - layout.reach - metrics.nameWidth / 2,
                      y: layout.seatY(seat))
    }

    private var accessibilityText: String {
        let crew = BoatRules.seatsTopToBottom(setup.type, orientation: orientation).compactMap { seat in
            names[seat].map { "\(BoatRules.seatName(seat, type: setup.type)) \($0)" }
        }
        let head = "\(setup.type.label) boat, \(orientation == .sternAtTop ? "stern" : "bow") at the top"
        return crew.isEmpty ? head : "\(head): " + crew.joined(separator: ", ")
    }
}
