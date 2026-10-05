//
//  CommentComposer.swift
//  Rowing Pals
//

import SwiftUI

/// The floating glass "Say something…" field with its round send button, pinned to the
/// bottom of the workout screen and the comments thread.
struct CommentComposer: View {
    @Binding var draft: String
    let onSend: (String) -> Void

    private var isEmpty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.gap) {
            TextField("Say something…", text: $draft)
                .textStyle(Typography.body)
                .foregroundStyle(Tokens.Ink.primary)
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .textStyle(Typography.buttonGlyph)
                    .foregroundStyle(Tokens.Base.dark)
                    .frame(width: Tokens.Size.sendButton, height: Tokens.Size.sendButton)
                    .background {
                        Circle().fill(isEmpty ? Tokens.Accent.brand.opacity(0.4) : Tokens.Accent.brand)
                    }
                    .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Send comment")
            .buttonStyle(.plain)
            .disabled(isEmpty)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: Tokens.Size.composer)
        .glassSurface(cornerRadius: Tokens.Radius.composer)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func send() {
        guard !isEmpty else { return }
        let text = draft
        draft = ""
        onSend(text)
    }
}
