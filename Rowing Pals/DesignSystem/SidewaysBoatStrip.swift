//
//  SidewaysBoatStrip.swift
//  Rowing Pals
//

import SwiftUI

/// The rower's boat on the Feed, on its side and scrolling sideways (decision 82): "‹ Stern" and
/// "Bow ›" above it; a boat longer than the card opens centred on the viewer's seat, fades at an
/// edge where there's more to see, and shows a thin bar for where you are along it. A boat that
/// fits (a pair, a double, a four) sits in the middle with nothing to scroll.
struct SidewaysBoatStrip: View {
    let setup: BoatSetup
    /// First names by seat (0 is the cox).
    let names: [Int: String]
    var mySeat: Int?

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
        let drawing = SidewaysBoatDrawing(setup: setup, names: names, highlightedSeat: mySeat)
        let layout = drawing.layout
        VStack(spacing: Tokens.Spacing.tight / 2) {
            HStack {
                BoatEndLabel(text: "‹ Stern")
                Spacer(minLength: 0)
                BoatEndLabel(text: "Bow ›")
            }
            ScrollView(.horizontal) {
                drawing
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
            .mask { fade }
            if geometry.overflows {
                bar
            }
        }
    }

    /// Opens with the viewer's seat in the middle (as near as the ends allow).
    private func centreOnMySeat(layout: SidewaysBoatDrawing.Layout) {
        guard !hasCentred, geometry.container > 0 else { return }
        hasCentred = true
        guard geometry.overflows, let mySeat, let x = layout.xs[mySeat] else { return }
        position.scrollTo(x: min(max(x - geometry.container / 2, 0), geometry.scrollable))
    }

    /// Fades the edge on each side where there's more boat to scroll to.
    private var fade: some View {
        let width = max(geometry.container, 1)
        let edge = min(Tokens.Boat.sidewaysFade / width, 0.5)
        let left = geometry.overflows && geometry.offset > 1
        let right = geometry.overflows && geometry.offset < geometry.scrollable - 1
        return LinearGradient(stops: [
            .init(color: left ? .clear : .black, location: 0),
            .init(color: .black, location: edge),
            .init(color: .black, location: 1 - edge),
            .init(color: right ? .clear : .black, location: 1)
        ], startPoint: .leading, endPoint: .trailing)
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
