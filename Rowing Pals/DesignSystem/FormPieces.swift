//
//  FormPieces.swift
//  Rowing Pals
//

import SwiftUI

/// The pieces the coach's forms share (New workout, practices, races and events, term dates): a
/// field's label, a section title, a footnote, the field's rounded box and a card holding a switch.

struct FormLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, Tokens.Grouped.rowPadding)
            .padding(.bottom, Tokens.Grouped.headerGap)
    }
}

struct FormSectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, Tokens.Grouped.rowPadding)
            .padding(.top, Tokens.Grouped.groupGap)
            .padding(.bottom, Tokens.Grouped.headerGap)
            .accessibilityAddTraits(.isHeader)
    }
}

struct FormFootnote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(Typography.statLabel)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, Tokens.Grouped.rowPadding)
            .padding(.top, Tokens.Grouped.headerGap)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A title, a line under it and a switch, in a card.
struct ToggleCard: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Grouped.radius, style: .continuous)

    var body: some View {
        HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(detail)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(Tokens.Accent.brand)
        }
        .padding(.horizontal, Tokens.Grouped.rowPadding)
        .padding(.vertical, Tokens.Spacing.tight)
        .frame(minHeight: Tokens.Grouped.rowHeight)
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }
}

extension View {
    /// A form field's rounded box: card fill, line border, input height.
    func formFieldBox() -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return self
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.input)
            .background(shape.fill(Tokens.Surface.card))
            .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: Tokens.Grouped.hairline) }
    }
}
