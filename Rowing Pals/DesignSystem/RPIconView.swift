//
//  RPIconView.swift
//  Rowing Pals
//

import SwiftUI

/// One of the app's icons (decision 80), drawn as the canvas draws it: the outline stroked with
/// round caps and joins, in the current foreground style, at a `Tokens.Icon` size.
struct RPIconView: View {
    let icon: RPIcon
    var size: CGFloat = Tokens.Icon.regular
    /// The stroke on the 24 grid; nil for the canvas's weight at this size.
    var weight: CGFloat?

    var body: some View {
        RPIconShape(icon: icon)
            .stroke(style: StrokeStyle(lineWidth: (weight ?? Tokens.Icon.stroke(for: size)) * size / 24,
                                       lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
