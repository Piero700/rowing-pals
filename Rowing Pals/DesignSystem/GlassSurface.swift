//
//  GlassSurface.swift
//  Rowing Pals
//

import SwiftUI

extension View {
    /// Wraps this view in native Liquid Glass — bars, sheets, chips, cards.
    /// The system provides the darkened edge and specular rim; hand-building
    /// those with blur/gradient stacks is exactly what this must not be.
    func glassSurface(cornerRadius: CGFloat = 24) -> some View {
        glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
