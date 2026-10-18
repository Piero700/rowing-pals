//
//  RPIconShape.swift
//  Rowing Pals
//

import SwiftUI

/// An `RPIcon`'s outline scaled from its 24 × 24 grid to the frame it's given (decision 80).
struct RPIconShape: Shape {
    let icon: RPIcon

    func path(in rect: CGRect) -> Path {
        icon.outline.applying(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
                .scaledBy(x: rect.width / 24, y: rect.height / 24)
        )
    }
}
