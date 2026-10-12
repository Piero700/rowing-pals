//
//  DurationTextField.swift
//  Rowing Pals
//

import SwiftUI

/// A time typed on the number pad with the colon put in as you type (5 0 0 → "5:00",
/// 2 0 0 0 → "20:00"); see `DurationEntry` (user, 2026-10-12). The text field underneath holds
/// only the digits typed — iOS never has to rewrite it mid-typing, so no keystroke is lost — and
/// the time is drawn over it, with a caret at the end while editing. `text` is the shown time.
struct DurationTextField: View {
    let placeholder: String
    @Binding var text: String

    @State private var digits = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            TextField("", text: $digits)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .accessibilityLabel(placeholder)
                .accessibilityValue(text)
            HStack(spacing: 1) {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundStyle(text.isEmpty ? Tokens.Ink.faint : Tokens.Ink.primary)
                if isFocused {
                    Rectangle()
                        .fill(Tokens.Accent.brand)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 2)
                }
            }
            .fixedSize()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onAppear { digits = DurationEntry.digits(from: text) }
        .onChange(of: digits) { _, newValue in
            let clean = DurationEntry.digits(from: newValue)
            if clean != newValue { digits = clean }
            text = DurationEntry.text(digits: clean)
        }
    }
}
