//
//  RosterFiltersSheet.swift
//  Rowing Pals
//

import SwiftUI

/// Coaching's filters (CoachSortSheet), behind the list's one Squad · Sort button (decision 62):
/// one squad or all, and the order — behind target, on target, best to worst, worst to best,
/// attendance, not logged or name — each with a line saying what it does. Changes apply on
/// Done; Reset goes back to all squads, behind target first.
struct RosterFiltersSheet: View {
    let squads: [Squad]
    /// How many rowers each squad holds, and the whole club.
    let rowerCount: Int
    let initialSquad: UUID?
    let initialSort: RosterSort
    let onApply: (UUID?, RosterSort) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var squad: UUID?
    @State private var sort: RosterSort

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(squads: [Squad], rowerCount: Int, squad: UUID?, sort: RosterSort, onApply: @escaping (UUID?, RosterSort) -> Void) {
        self.squads = squads
        self.rowerCount = rowerCount
        self.initialSquad = squad
        self.initialSort = sort
        self.onApply = onApply
        _squad = State(initialValue: squad)
        _sort = State(initialValue: sort)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button("Reset") {
                        squad = nil
                        sort = .behindTarget
                    }
                    .buttonStyle(.rpText)
                    Spacer()
                    Button("Done") {
                        onApply(squad, sort)
                        dismiss()
                    }
                    .buttonStyle(.rpText)
                    .fontWeight(.semibold)
                }
                Text("Show")
                    .textStyle(Typography.navTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, Tokens.Spacing.tight)
            .padding(.top, Tokens.Spacing.loose)
            .frame(minHeight: Tokens.Size.minTap)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    title("Squad")
                        .padding(.top, Tokens.Spacing.screen)
                    VStack(spacing: 0) {
                        choiceRow(name: "All squads", detail: Self.rowers(rowerCount), isSelected: squad == nil) { squad = nil }
                        ForEach(squads) { item in
                            Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                            choiceRow(name: item.name, detail: Self.rowers(item.memberIds.count), isSelected: squad == item.id) { squad = item.id }
                        }
                    }
                    .background(Self.cardShape.fill(Tokens.Surface.card))
                    .clipShape(Self.cardShape)
                    .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }

                    title("Sort by")
                        .padding(.top, Tokens.Spacing.group)
                    VStack(spacing: 0) {
                        ForEach(Array(RosterSort.allCases.enumerated()), id: \.element) { index, option in
                            if index > 0 { Rectangle().fill(Tokens.Surface.line).frame(height: 1) }
                            choiceRow(name: option.label, detail: option.detail, isSelected: sort == option) { sort = option }
                        }
                    }
                    .background(Self.cardShape.fill(Tokens.Surface.card))
                    .clipShape(Self.cardShape)
                    .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                }
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.bottom, Tokens.Spacing.group)
            }
            .scrollIndicators(.hidden)
        }
        .background(Tokens.Base.ground)
        .presentationBackground(Tokens.Base.ground)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, Tokens.Spacing.tight)
            .accessibilityAddTraits(.isHeader)
    }

    private static func rowers(_ count: Int) -> String {
        "\(count) rower\(count == 1 ? "" : "s")"
    }

    private func choiceRow(name: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(detail)
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RPIconView(icon: .check, size: Tokens.Icon.small)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Tokens.Size.checkmark)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .frame(minHeight: Tokens.Size.rowCompact)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
