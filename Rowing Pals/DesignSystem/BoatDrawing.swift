//
//  BoatDrawing.swift
//  Rowing Pals
//

import SwiftUI

/// A boat drawn upright, bow at the top, seats a seat-length apart (decision 67; CoachBoats,
/// CoachBoatEdit, RowerBoat): the hull on a pale band, each seat's rigger and blade on its oar's
/// side (stroke side on the left, bow side on the right; a sculling boat's on both), the seat
/// marks B · 2 · 3 · S, and the cox's square at the stern. The small drawing writes first names
/// beside the seats; the large one leaves room for the crewing screen's own buttons.
struct BoatDrawing: View {
    let type: BoatType
    let rigging: Rigging
    var metrics: Tokens.Boat.Metrics = Tokens.Boat.small
    /// First names by seat, for the small drawing.
    var names: [Int: String] = [:]
    /// The viewer's own seat, filled in brand.
    var highlightedSeat: Int?
    /// The seat being chosen for, dashed.
    var selectedSeat: Int?
    /// Seats with nobody in them yet, dashed when drawn large.
    var emptySeats: Set<Int> = []

    var body: some View {
        let layout = Layout(type: type, metrics: metrics)
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in draw(in: &context, layout: layout) }
            ForEach(BoatRules.seats(type), id: \.self) { seat in
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

        var centreX: CGFloat { metrics.width / 2 }
        var lastRowerY: CGFloat { seatY(type.rowers) }
        var height: CGFloat { lastRowerY + metrics.stern + (type.isCoxed ? metrics.coxSpace : 0) }

        /// A seat's centre from the top; the cox sits below stroke.
        func seatY(_ seat: Int) -> CGFloat {
            if seat == 0 { return lastRowerY + metrics.stern - metrics.coxSize / 2 + (type.isCoxed ? metrics.coxSpace / 2 : 0) }
            return metrics.firstSeat + CGFloat(seat - 1) * metrics.seatSpacing
        }
    }

    private func draw(in context: inout GraphicsContext, layout: Layout) {
        let m = metrics
        let x = layout.centreX
        let height = layout.height
        let half = m.hullWidth / 2
        let inset: CGFloat = m.seatRadius / 2

        // The pale band behind the boat.
        let band = CGRect(x: x - m.bandWidth / 2, y: 0, width: m.bandWidth, height: height)
        context.fill(Path(roundedRect: band, cornerRadius: m.bandWidth / 2), with: .color(Tokens.Accent.brandSoft))

        // The hull: a point at the bow, straight sides, a rounded stern.
        var hull = Path()
        let top = inset
        let bottom = height - inset
        hull.move(to: CGPoint(x: x, y: top))
        hull.addQuadCurve(to: CGPoint(x: x + half, y: top + m.bowTaper), control: CGPoint(x: x + half, y: top + m.bowTaper * 0.45))
        hull.addLine(to: CGPoint(x: x + half, y: bottom - half))
        hull.addQuadCurve(to: CGPoint(x: x - half, y: bottom - half), control: CGPoint(x: x, y: bottom + half / 2))
        hull.addLine(to: CGPoint(x: x - half, y: top + m.bowTaper))
        hull.addQuadCurve(to: CGPoint(x: x, y: top), control: CGPoint(x: x - half, y: top + m.bowTaper * 0.45))
        hull.closeSubpath()
        context.fill(hull, with: .color(Tokens.Surface.raised))
        context.stroke(hull, with: .color(Tokens.Surface.line), lineWidth: Tokens.Boat.lineWidth)

        for seat in BoatRules.seats(type) {
            let y = layout.seatY(seat)
            if seat == 0 {
                drawCox(in: &context, centre: CGPoint(x: x, y: y))
                continue
            }
            if type.isSculling {
                drawRigger(in: &context, from: CGPoint(x: x + half, y: y), toRight: true)
                drawRigger(in: &context, from: CGPoint(x: x - half, y: y), toRight: false)
            } else {
                let right = BoatRules.isOnRight(seat: seat, type: type, rigging: rigging)
                drawRigger(in: &context, from: CGPoint(x: right ? x + half : x - half, y: y), toRight: right)
            }
            drawSeat(in: &context, seat: seat, centre: CGPoint(x: x, y: y))
        }
    }

    private func drawRigger(in context: inout GraphicsContext, from start: CGPoint, toRight: Bool) {
        let m = metrics
        let direction: CGFloat = toRight ? 1 : -1
        let end = CGPoint(x: start.x + direction * m.riggerReach, y: start.y + m.riggerDrop)
        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        context.stroke(line, with: .color(Tokens.Ink.secondary), style: StrokeStyle(lineWidth: Tokens.Boat.riggerLineWidth, lineCap: .round))
        let blade = CGRect(x: -m.bladeLength / 2, y: -m.bladeDepth / 2, width: m.bladeLength, height: m.bladeDepth)
        var bladeContext = context
        bladeContext.translateBy(x: end.x + direction * m.bladeLength / 2.5, y: end.y + 1)
        bladeContext.rotate(by: .degrees(direction * 14))
        bladeContext.fill(Path(ellipseIn: blade), with: .color(Tokens.Ink.secondary))
    }

    private func drawSeat(in context: inout GraphicsContext, seat: Int, centre: CGPoint) {
        let r = metrics.seatRadius
        let circle = Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
        let isMine = seat == highlightedSeat
        let isSelected = seat == selectedSeat
        let isEmpty = emptySeats.contains(seat)
        if isMine {
            context.fill(circle, with: .color(Tokens.Accent.brand))
        } else if isSelected {
            context.fill(circle, with: .color(Tokens.Accent.brandSoft))
            context.stroke(circle, with: .color(Tokens.Accent.brand),
                           style: StrokeStyle(lineWidth: Tokens.Boat.selectedLineWidth, dash: Tokens.Boat.dash))
        } else {
            context.fill(circle, with: .color(Tokens.Surface.card))
            context.stroke(circle, with: .color(isEmpty ? Tokens.Ink.secondary : Tokens.Ink.primary),
                           style: StrokeStyle(lineWidth: Tokens.Boat.lineWidth, dash: isEmpty ? Tokens.Boat.dash : []))
        }
        let ink: Color = isMine ? Tokens.Ink.onBrand : (isSelected ? Tokens.Accent.brand : Tokens.Ink.primary)
        let mark = Text(BoatRules.seatMark(seat, type: type))
            .font(.system(size: metrics.markFont, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(ink)
        context.draw(mark, at: centre)
    }

    /// The cox: a rounded square at the stern.
    private func drawCox(in context: inout GraphicsContext, centre: CGPoint) {
        let size = metrics.coxSize
        let rect = CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
        let square = Path(roundedRect: rect, cornerRadius: size / 3)
        let isMine = highlightedSeat == 0
        let isSelected = selectedSeat == 0
        context.fill(square, with: .color(isMine ? Tokens.Accent.brand : (isSelected ? Tokens.Accent.brandSoft : Tokens.Surface.card)))
        context.stroke(square, with: .color(isSelected || isMine ? Tokens.Accent.brand : Tokens.Ink.primary),
                       style: StrokeStyle(lineWidth: isSelected ? Tokens.Boat.selectedLineWidth : Tokens.Boat.lineWidth,
                                          dash: isSelected || emptySeats.contains(0) ? Tokens.Boat.dash : []))
        let mark = Text("C")
            .font(.system(size: metrics.markFont, weight: .bold))
            .foregroundStyle(isMine ? Tokens.Ink.onBrand : (isSelected ? Tokens.Accent.brand : Tokens.Ink.primary))
        context.draw(mark, at: centre)
    }

    private func nameLabel(_ name: String, seat: Int, layout: Layout) -> some View {
        let right = seat == 0 || BoatRules.isOnRight(seat: seat, type: type, rigging: rigging)
        let offset = metrics.bandWidth / 2 + metrics.nameGap
        let isMine = seat == highlightedSeat
        return Text(name)
            .textStyle(Typography.chip)
            .fontWeight(isMine ? .bold : .semibold)
            .foregroundStyle(isMine ? Tokens.Accent.brand : Tokens.Ink.primary)
            .lineLimit(1)
            .frame(width: metrics.nameWidth, alignment: right ? .leading : .trailing)
            .position(x: right ? layout.centreX + offset + metrics.nameWidth / 2 : layout.centreX - offset - metrics.nameWidth / 2,
                      y: layout.seatY(seat))
    }

    private var accessibilityText: String {
        let crew = BoatRules.seats(type).compactMap { seat in
            names[seat].map { "\(BoatRules.seatName(seat, type: type)) \($0)" }
        }
        let head = "\(type.label) boat, bow at the top"
        return crew.isEmpty ? head : "\(head): " + crew.joined(separator: ", ")
    }
}
