//
//  NotepadTextBlockView.swift
//  Rowing Pals
//

import SwiftUI

/// A text box a coach added to the notepad (decision 96): a card that grows as they write, with ✕
/// to take it off the page.
struct NotepadTextBlockView: View {
    @Binding var block: NotepadBlock
    let onRemove: () -> Void

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Notepad.tableRadius, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Text")
                    .textStyle(Typography.kicker)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer(minLength: 0)
                NotepadRemoveButton(label: "Remove text", action: onRemove)
            }
            TextField("Write anything…", text: $block.text, axis: .vertical)
                .lineLimit(Tokens.Notepad.textMinLines...)
                .textStyle(Typography.body)
                .foregroundStyle(Tokens.Ink.primary)
                .onChange(of: block.text) { _, value in
                    let clipped = NotepadRules.clipped(value, to: NotepadRules.maxTextLength)
                    if clipped != value { block.text = clipped }
                }
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }
}
