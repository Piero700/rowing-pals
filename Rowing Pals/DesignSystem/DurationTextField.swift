//
//  DurationTextField.swift
//  Rowing Pals
//

import SwiftUI

/// Every workout time in the app is typed here (user, 2026-10-12 and 2026-10-14): on the number
/// pad, with the colon put in as you type (5 0 0 → "5:00", 2 0 0 0 → "20:00"); see
/// `DurationEntry`. With `allowsTenths` the decimal key adds the monitor's tenth (7 0 2 . 4 →
/// "7:02.4"). The text field underneath holds only what was typed — iOS never has to rewrite it
/// mid-typing, so no keystroke is lost — and the time is drawn over it, with a caret at the end
/// while editing. `text` is the shown time. Focus is the caller's, so a screen can move it.
struct DurationTextField<Field: Hashable>: View {
    let placeholder: String
    @Binding var text: String
    let allowsTenths: Bool
    let focus: FocusState<Field?>.Binding
    let field: Field
    /// Where the time sits in the field: on the left, or on the right of a grouped row.
    let alignment: Alignment

    @State private var entry = ""

    init(placeholder: String, text: Binding<String>, allowsTenths: Bool = false,
         focus: FocusState<Field?>.Binding, field: Field, alignment: Alignment = .leading) {
        self.placeholder = placeholder
        _text = text
        self.allowsTenths = allowsTenths
        self.focus = focus
        self.field = field
        self.alignment = alignment
    }

    private var isFocused: Bool { focus.wrappedValue == field }

    var body: some View {
        ZStack(alignment: alignment) {
            TextField("", text: $entry)
                .keyboardType(allowsTenths ? .decimalPad : .numberPad)
                .focused(focus, equals: field)
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
        .onTapGesture { focus.wrappedValue = field }
        .onAppear { entry = DurationEntry.entry(from: text, allowsTenths: allowsTenths) }
        .onChange(of: entry) { _, newValue in
            let clean = DurationEntry.entry(from: newValue, allowsTenths: allowsTenths)
            if clean != newValue { entry = clean }
            text = DurationEntry.text(entry: clean)
        }
        // The screen may put a time back (an unreadable one on leaving the field): follow it.
        .onChange(of: text) { _, newValue in
            guard DurationEntry.text(entry: entry) != newValue else { return }
            entry = DurationEntry.entry(from: newValue, allowsTenths: allowsTenths)
        }
    }
}
