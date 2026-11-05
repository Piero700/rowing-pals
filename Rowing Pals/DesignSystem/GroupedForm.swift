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
