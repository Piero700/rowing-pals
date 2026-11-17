//
//  ReviewCaptionField.swift
//  Rowing Pals
//

import SwiftUI

/// v3 caption box on Review session: at least 82 pt tall, card fill, 1 pt line, radius 24.
struct ReviewCaptionField: View {
    @Bindable var viewModel: ReviewSheetViewModel

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)

    var body: some View {
        TextField("How did it feel?", text: $viewModel.caption, axis: .vertical)
            .textStyle(Typography.bodyV3)
            .foregroundStyle(Tokens.Ink.primary)
            .lineLimit(3...8)
            .padding(.horizontal, 14)
            .padding(.vertical, Tokens.Spacing.loose)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(Self.shape.fill(Tokens.Surface.card))
            .overlay { Self.shape.strokeBorder(Tokens.Surface.line, lineWidth: Tokens.Grouped.hairline) }
    }
}
