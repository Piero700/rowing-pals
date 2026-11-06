//
//  SidewaysBoatStrip.swift
//  Rowing Pals
//

import SwiftUI

/// A boat on its side and scrolling sideways (decision 82): "‹ Stern" and "Bow ›" above it; a boat
/// longer than the card opens centred on the viewer's seat (or at the stern), and shows a thin bar for
/// where you are along it. A boat that fits (a pair, a
/// double, a four) sits in the middle with nothing to scroll. The rower's Feed, the Boats tab and a
/// session's boats show it with names; the crewing screen lays its seat buttons over it (decision 88).
struct SidewaysBoatStrip<Overlay: View>: View {
    let setup: BoatSetup
    /// First names by seat (0 is the cox).
    let names: [Int: String]
    var mySeat: Int?
    /// "#RRGGBB" for the hull (decision 87).
    var colour: String?
    var style: SidewaysBoatDrawing.Style = .names
    var selectedSeat: Int?
    var emptySeats: Set<Int> = []
    /// Drawn over the boat, in the drawing's own coordinates (the crewing screen's buttons).
    @ViewBuilder var overlay: (SidewaysBoatDrawing.Layout) -> Overlay

    /// Where the strip is scrolled to, how long the boat is and how wide the card is.
    private struct Geometry: Equatable {
        var offset: CGFloat = 0
        var content: CGFloat = 0
        var container: CGFloat = 0
        var overflows: Bool { content > container + 1 }
        var scrollable: CGFloat { max(content - container, 0) }
    }

    @State private var geometry = Geometry()
    @State private var position = ScrollPosition(edge: .leading)
    @State private var hasCentred = false

    var body: some View {
        let drawing = SidewaysBoatDrawing(setup: setup, names: names, highlightedSeat: mySeat, colour: colour,
                                          selectedSeat: selectedSeat, emptySeats: emptySeats, style: style)
        let layout = drawing.layout
        VStack(spacing: Tokens.Spacing.tight / 2) {
            HStack {
                BoatEndLabel(text: "‹ Stern")
                Spacer(minLength: 0)
                BoatEndLabel(text: "Bow ›")
            }
            ScrollView(.horizontal) {
                ZStack(alignment: .topLeading) {
                    drawing
                    overlay(layout)
                }
                .frame(width: layout.width, height: layout.height, alignment: .topLeading)
                // A boat that fits sits in the middle of the card.
                .frame(minWidth: geometry.container)
            }
            .scrollIndicators(.hidden)
            .scrollPosition($position)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onScrollGeometryChange(for: Geometry.self) { scroll in
                Geometry(offset: scroll.contentOffset.x, content: scroll.contentSize.width, container: scroll.containerSize.width)
            } action: { _, new in
                geometry = new
                centreOnMySeat(layout: layout)
            }
            // Crewing doesn't scroll the boat when the next seat is chosen: it stays where the coach
            // left it (user, 2026-11-03).
            if geometry.overflows {
                bar
            }
        }
    }

    /// Opens with the viewer's seat in the middle (as near as the ends allow); when crewing, the seat
    /// being chosen for.
    private func centreOnMySeat(layout: SidewaysBoatDrawing.Layout) {
        guard !hasCentred, geometry.container > 0 else { return }
        hasCentred = true
        guard let seat = mySeat ?? selectedSeat else { return }
        scroll(to: seat, layout: layout)
    }

    private func scroll(to seat: Int, layout: SidewaysBoatDrawing.Layout) {
        guard geometry.overflows, let x = layout.xs[seat] else { return }
        position.scrollTo(x: min(max(x - geometry.container / 2, 0), geometry.scrollable))
    }

    /// A thin track with a thumb for the part of the boat on screen.
    private var bar: some View {
        GeometryReader { proxy in
            let track = proxy.size.width
            let thumb = track * geometry.container / max(geometry.content, 1)
            let x = geometry.scrollable > 0 ? (geometry.offset / geometry.scrollable) * (track - thumb) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Tokens.Surface.raised)
                Capsule().fill(Tokens.Ink.secondary)
                    .frame(width: thumb)
                    .offset(x: min(max(x, 0), track - thumb))
            }
        }
        .frame(height: Tokens.Boat.sidewaysBarHeight)
        .accessibilityHidden(true)
    }
}

extension SidewaysBoatStrip where Overlay == EmptyView {
    /// A boat with its crew's names under the seats.
    init(setup: BoatSetup, names: [Int: String], mySeat: Int? = nil, colour: String? = nil) {
        self.init(setup: setup, names: names, mySeat: mySeat, colour: colour) { _ in EmptyView() }
    }
}
