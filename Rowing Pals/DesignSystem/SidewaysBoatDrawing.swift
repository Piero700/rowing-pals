//
//  SidewaysBoatDrawing.swift
//  Rowing Pals
//

import SwiftUI

/// A crew boat on its side (decision 82), drawn like a real boat with the oars at the catch (decision
/// 86, `SidewaysBoatParts`): the stern on the left and the bow with its ball on the right; stroke-side
/// oars up and bow side down, as the crew sees it facing the stern (sculls have one each side); each
/// seat's mark in its circle (the cox's square at the stern) and the rower's first name under it,
/// with Cox, Stroke and Bow named. The viewer's seat is filled in brand blue and their name is blue;
/// the hull takes the coach's colour for the boat (decision 87). Every boat is drawn this way, on
/// the Feed and on the coach's screens (decision 88): the crewing screen spaces the seats wider and
/// puts its own seat buttons where the names go, with the seat being chosen dashed and empty seats
/// dashed grey. Its width grows with the boat; `SidewaysBoatStrip` scrolls it.
struct SidewaysBoatDrawing: View {
    let setup: BoatSetup
    /// First names by seat (0 is the cox).
    let names: [Int: String]
    var highlightedSeat: Int?
    /// "#RRGGBB" for the hull, or nil for the plain boat.
    var colour: String?
    /// Crewing (decision 88): the seat being chosen for, and seats with nobody in them yet.
    var selectedSeat: Int?
    var emptySeats: Set<Int> = []
    /// The seat spacing and height: the Feed's, or the crewing screen's.
    var style: Style = .names

    enum Style {
        /// First names under the seats (the Feed, the Boats tab, a session's boats).
        case names
        /// Wider seats and no names: the crewing screen puts its seat buttons there.
        case crewing

        var seatSpacing: CGFloat { self == .names ? Tokens.Boat.sidewaysSeatSpacing : Tokens.Boat.crewSeatSpacing }
        /// The cox sits closer to stroke, except when crewing, where every seat needs room for its button.
        var coxStep: CGFloat { self == .names ? Tokens.Boat.sidewaysCoxStep : Tokens.Boat.crewSeatSpacing }
        var height: CGFloat { self == .names ? Tokens.Boat.sidewaysHeight : Tokens.Boat.crewHeight }
    }

    /// Each seat's centre along the boat, stern (left) to bow (right), and the drawing's width.
    struct Layout {
        let xs: [Int: CGFloat]
        let width: CGFloat
        let height: CGFloat

        init(type: BoatType, style: Style = .names) {
            let order = BoatRules.seatsSternToBow(type)
            var xs: [Int: CGFloat] = [:]
            var x = Tokens.Boat.sidewaysEnd
            for (index, seat) in order.enumerated() {
                xs[seat] = x
                if index + 1 < order.count {
                    x += (seat == 0 || order[index + 1] == 0) ? style.coxStep : style.seatSpacing
                }
            }
            if type.rowers == 1 {
                // A single keeps a single's long hull, the seat a little towards the stern.
                width = Tokens.Boat.sidewaysSingleLength
                xs[1] = width * Tokens.Boat.singleSeatAt
            } else {
                width = x + Tokens.Boat.sidewaysBowEnd
            }
            self.xs = xs
            height = style.height
        }
    }

    var layout: Layout { Layout(type: setup.type, style: style) }

    var body: some View {
        let layout = layout
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in draw(in: &context, layout: layout) }
                .frame(width: layout.width, height: layout.height)
            if style == .names {
                ForEach(layout.xs.keys.sorted(), id: \.self) { seat in
                    nameLabel(seat, x: layout.xs[seat] ?? 0)
                }
            }
        }
        .frame(width: layout.width, height: layout.height, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func draw(in context: inout GraphicsContext, layout: Layout) {
        let y = Tokens.Boat.sidewaysHullCentre
        let hull = BoatPalette.color(colour)
        SidewaysBoatParts.drawHull(in: &context, left: 3, right: layout.width - 3, y: y, colour: hull)

        // The open deck between the first and last seats.
        let seatXs = layout.xs.values
        if let first = seatXs.min(), let last = seatXs.max() {
            SidewaysBoatParts.drawDeck(in: &context, from: first - Tokens.Boat.sidewaysSeatSpacing * 0.4,
                                       to: last + Tokens.Boat.sidewaysSeatSpacing * 0.4, y: y, colour: hull)
        }

        for seat in 1...setup.type.rowers {
            guard let x = layout.xs[seat] else { continue }
            if setup.type.isSculling {
                SidewaysBoatParts.drawOar(in: &context, seatX: x, y: y, up: true)
                SidewaysBoatParts.drawOar(in: &context, seatX: x, y: y, up: false)
            } else {
                // Stroke side up: the crew faces the stern (left), so their stroke side is above.
                SidewaysBoatParts.drawOar(in: &context, seatX: x, y: y,
                                          up: BoatRules.side(ofSeat: seat, setup: setup) == .stroke)
            }
        }
        for (seat, x) in layout.xs {
            drawSeat(in: &context, seat: seat, centre: CGPoint(x: x, y: y))
        }
    }

    private func drawSeat(in context: inout GraphicsContext, seat: Int, centre: CGPoint) {
        let r = Tokens.Boat.sidewaysSeatRadius
        let isMine = seat == highlightedSeat
        let isSelected = seat == selectedSeat
        let isEmpty = emptySeats.contains(seat)
        let shape: Path
        if seat == 0 {
            let size = Tokens.Boat.sidewaysCoxSeat
            shape = Path(roundedRect: CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size),
                         cornerRadius: Tokens.Boat.sidewaysCoxSeatCorner)
        } else {
            shape = Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
        }
        if isMine {
            context.fill(shape, with: .color(Tokens.Accent.brand))
        } else if isSelected {
            context.fill(shape, with: .color(Tokens.Surface.card))
            context.fill(shape, with: .color(Tokens.Accent.brandSoft))
            context.stroke(shape, with: .color(Tokens.Accent.brand),
                           style: StrokeStyle(lineWidth: Tokens.Boat.selectedLineWidth, dash: Tokens.Boat.dash))
        } else {
            context.fill(shape, with: .color(Tokens.Surface.card))
            context.stroke(shape, with: .color(isEmpty ? Tokens.Ink.secondary : Tokens.Ink.primary),
                           style: StrokeStyle(lineWidth: Tokens.Boat.sidewaysSeatLine, dash: isEmpty ? Tokens.Boat.dash : []))
        }
        let ink: Color = isMine ? Tokens.Ink.onBrand : (isSelected ? Tokens.Accent.brand : (isEmpty ? Tokens.Ink.secondary : Tokens.Ink.primary))
        let mark = Text(BoatRules.seatMark(seat, type: setup.type))
            .font(.system(size: Tokens.Boat.sidewaysMarkFont, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(ink)
        context.draw(mark, at: centre)
    }

    private func nameLabel(_ seat: Int, x: CGFloat) -> some View {
        let isMine = seat == highlightedSeat
        let width = Tokens.Boat.sidewaysSeatSpacing - 4
        return VStack(spacing: 0) {
            Text(names[seat] ?? "—")
                .textStyle(Typography.chip)
                .fontWeight(isMine ? .bold : .semibold)
                .foregroundStyle(isMine ? Tokens.Accent.brand : Tokens.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if let role = BoatRules.role(seat, type: setup.type) {
                Text(role)
                    .textStyle(Typography.navLabel)
                    .fontWeight(.regular)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .frame(width: width)
        .offset(x: x - width / 2, y: Tokens.Boat.sidewaysNameTop)
    }

    /// "Stern to bow: cox Kate, stroke Piero, seat 7 Tom, … bow Ben. You’re at 3 in this boat."
    private var accessibilityText: String {
        let order = layout.xs.keys.sorted { (layout.xs[$0] ?? 0) < (layout.xs[$1] ?? 0) }
        let crew = order.map { seat in
            "\(BoatRules.seatName(seat, type: setup.type).lowercased()) \(names[seat] ?? "empty")"
        }
        let painted = BoatPalette.name(colour).map { "\($0) \(setup.type.label) boat. " } ?? ""
        let mine = highlightedSeat.map { " \(BoatRules.seatPhrase($0, type: setup.type)) this boat." } ?? ""
        return painted + "Stern to bow: " + crew.joined(separator: ", ") + "." + mine
    }
}
