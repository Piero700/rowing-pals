//
//  GroupedForm.swift
//  Rowing Pals
//

import SwiftUI

/// The compact grouped-rows style (user, 2026-11-05): a group is one card with small corners and
/// a hairline edge, its rows divided by hairlines that start where the text does, labels on the
/// left and values on the right. First used on setting a land session.
struct GroupedSection<Content: View>: View {
    var header: String?
    var footer: String?
    @ViewBuilder var content: () -> Content

    private static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Tokens.Grouped.radius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Grouped.headerGap) {
            if let header {
                Text(header)
                    .textStyle(Typography.sectionTitle)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, Tokens.Grouped.rowPadding)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content() }
                .background(Self.shape.fill(Tokens.Surface.card))
                .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
                .clipShape(Self.shape)
            if let footer {
                Text(footer)
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, Tokens.Grouped.rowPadding)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The hairline between two rows of a group.
struct GroupedDivider: View {
    var body: some View {
        Rectangle()
            .fill(Tokens.Surface.line)
            .frame(height: Tokens.Grouped.hairline)
            .padding(.leading, Tokens.Grouped.dividerInset)
    }
}

/// One row: a label on the left and whatever goes on the right (a value, a control).
struct GroupedRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            Text(label)
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
            Spacer(minLength: Tokens.Spacing.tight)
            trailing()
        }
        .padding(.horizontal, Tokens.Grouped.rowPadding)
        .frame(minHeight: Tokens.Grouped.rowHeight)
    }
}

/// A row's value, with a chevron when tapping it opens something.
struct GroupedValue: View {
    let text: String
    var isPlaceholder = false
    var showsChevron = true

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .textStyle(Typography.detail)
                .tabularNumerals()
                .foregroundStyle(isPlaceholder ? Tokens.Accent.brand : Tokens.Ink.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if showsChevron {
                RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                    .foregroundStyle(Tokens.Ink.faint)
            }
        }
    }
}

/// A typed value in a row: the label on the left, the field on the right.
struct GroupedTextRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        GroupedRow(label: label) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textStyle(Typography.detail)
                .tabularNumerals()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Tokens.Ink.primary)
        }
    }
}

/// Longer writing (notes, a plan, an announcement's text) across the whole row, growing as it's typed.
struct GroupedNotesRow: View {
    let placeholder: String
    @Binding var text: String
    var lines: ClosedRange<Int> = 1...6

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .textStyle(Typography.detail)
            .foregroundStyle(Tokens.Ink.primary)
            .lineLimit(lines)
            .padding(.horizontal, Tokens.Grouped.rowPadding)
            .padding(.vertical, Tokens.Spacing.loose)
            .frame(maxWidth: .infinity, minHeight: Tokens.Grouped.rowHeight, alignment: .leading)
    }
}

/// A switch, with an optional line under its label.
struct GroupedToggleRow: View {
    let label: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .textStyle(Typography.detail)
                    .foregroundStyle(Tokens.Ink.primary)
                if let detail {
                    Text(detail)
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(label, isOn: $isOn)
                .labelsHidden()
                .tint(Tokens.Accent.brand)
        }
        .padding(.horizontal, Tokens.Grouped.rowPadding)
        .padding(.vertical, detail == nil ? 0 : Tokens.Spacing.tight)
        .frame(minHeight: Tokens.Grouped.rowHeight)
    }
}

/// A row that does something: blue, or red for a destructive action, centred or leading.
struct GroupedButtonRow: View {
    let title: String
    var isDestructive = false
    var isCentred = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(Typography.detail)
                .foregroundStyle(isDestructive ? Tokens.System.error : Tokens.Accent.brand)
                .frame(maxWidth: .infinity, minHeight: Tokens.Grouped.rowHeight,
                       alignment: isCentred ? .center : .leading)
                .padding(.horizontal, Tokens.Grouped.rowPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
    }
}

/// A row of choices as small chips (quick picks, squads), wrapping onto more lines when needed.
struct GroupedChipsRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        WrapLayout(spacing: Tokens.Spacing.tight) { content() }
            .padding(.horizontal, Tokens.Grouped.rowPadding)
            .padding(.vertical, Tokens.Spacing.tight)
            .frame(maxWidth: .infinity, minHeight: Tokens.Grouped.rowHeight, alignment: .leading)
    }
}

/// A Save (or Set, Post…) text button for a screen's header, greyed out until the form can be saved.
struct HeaderSaveButton: View {
    let title: String
    var isSaving = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSaving { ProgressView() } else { Text(title) }
        }
        .buttonStyle(.rpText)
        .disabled(isSaving || isDisabled)
        .frame(minWidth: Tokens.Size.minTap, minHeight: Tokens.Size.minTap)
    }
}

/// An error under a form's groups.
struct GroupedError: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.System.error)
            .padding(.horizontal, Tokens.Grouped.rowPadding)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// A grey note under a group, for a footer that only sometimes shows.
    @ViewBuilder
    func groupedFooter(_ text: String?) -> some View {
        if let text {
            VStack(alignment: .leading, spacing: Tokens.Grouped.headerGap) {
                self
                Text(text)
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, Tokens.Grouped.rowPadding)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            self
        }
    }
}

/// A grey note on its own, between groups.
struct GroupedNote: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(Typography.statLabel)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, Tokens.Grouped.rowPadding)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// An action at the foot of a card (Open notepad, Take register): a hairline, then the icon, the
/// action in blue and a chevron, in place of a big button (decision 97, app-wide). Sits inside the
/// card's own padding.
struct CardLinkRow: View {
    let icon: RPIcon
    let title: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Tokens.Surface.line)
                .frame(height: Tokens.Grouped.hairline)
            Button(action: action) {
                HStack(spacing: Tokens.Spacing.tight) {
                    RPIconView(icon: icon, size: Tokens.Icon.small)
                    Text(title)
                    Spacer(minLength: 0)
                    RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                        .foregroundStyle(Tokens.Ink.faint)
                }
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Accent.brand)
                .frame(minHeight: Tokens.Size.minTap)
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())
        }
    }
}
