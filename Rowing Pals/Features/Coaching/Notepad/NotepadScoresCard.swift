//
//  NotepadScoresCard.swift
//  Rowing Pals
//

import SwiftUI

/// The notepad's Scores table (CoachNotepad, decision 96): one row per rower in erg order — their
/// erg number and name stay put on the left — and one box per rep, which scrolls sideways when
/// there are more reps than fit. A box shows the coach's score, else the rower's own post (with
/// a brand dot), "out" for sat out, or "–". Tapping a box opens the entry bar.
struct NotepadScoresCard: View {
    let viewModel: NotepadViewModel
    let onSelect: (NotepadRules.Spot) -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let headerHeight: CGFloat = Tokens.Size.chip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Scores")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Tokens.Spacing.tight)
                Text("split /500m")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.top, Tokens.Spacing.loose)
            .padding(.bottom, Tokens.Spacing.tight)

            if viewModel.rowers.isEmpty {
                Text("Nobody is in this workout yet.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, Tokens.Spacing.card)
                    .padding(.bottom, Tokens.Spacing.card)
            } else {
                // As on the board, the names take whatever the boxes leave, and the boxes sit
                // against the card's right edge: the boxes take their full width first (up to
                // what's left after the narrowest names column) and scroll sideways beyond it.
                HStack(alignment: .top, spacing: 0) {
                    namesColumn
                        .frame(minWidth: Tokens.Notepad.ergColumn + 4 + Tokens.Notepad.nameColumn,
                               maxWidth: .infinity, alignment: .leading)
                    ScrollView(.horizontal) {
                        boxesColumns
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .frame(maxWidth: Tokens.Notepad.cellWidth * CGFloat(viewModel.reps.count))
                    .layoutPriority(1)
                }
                .padding(.horizontal, Tokens.Spacing.tight)

                legend
            }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .clipShape(Self.cardShape)
    }

    // MARK: - Columns

    private var namesColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text("#")
                    .frame(width: Tokens.Notepad.ergColumn)
                Text("Rower")
            }
            .textStyle(Typography.tag)
            .foregroundStyle(Tokens.Ink.secondary)
            .frame(height: Self.headerHeight)
            ForEach(Array(viewModel.rowers.enumerated()), id: \.element.id) { index, rower in
                VStack(alignment: .leading, spacing: 0) {
                    Divider().overlay(Tokens.Surface.cardEdge)
                    HStack(spacing: 4) {
                        Text("\(index + 1)")
                            .textStyle(Typography.statLabel)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.faint)
                            .frame(width: Tokens.Notepad.ergColumn)
                        Text(rower.shortName)
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, minHeight: Tokens.Notepad.rowHeight - 1,
                           maxHeight: Tokens.Notepad.rowHeight - 1, alignment: .leading)
                }
                .id(rower.id)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Erg \(index + 1), \(rower.name)")
            }
        }
    }

    private var boxesColumns: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(viewModel.reps.indices, id: \.self) { rep in
                    Text(viewModel.reps.count > 1 ? "\(rep + 1)" : "Score")
                        .textStyle(Typography.tag)
                        .tabularNumerals()
                        .foregroundStyle(viewModel.selection?.rep == rep ? Tokens.Accent.brand : Tokens.Ink.secondary)
                        .frame(width: Tokens.Notepad.cellWidth)
                }
            }
            .frame(height: Self.headerHeight)
            ForEach(viewModel.rowers) { rower in
                VStack(spacing: 0) {
                    Divider().overlay(Tokens.Surface.cardEdge)
                    HStack(spacing: 0) {
                        ForEach(viewModel.reps.indices, id: \.self) { rep in
                            box(NotepadRules.Spot(rowerId: rower.id, rep: rep), rower: rower)
                        }
                    }
                    .frame(height: Tokens.Notepad.rowHeight - 1)
                }
            }
        }
    }

    // MARK: - One box

    private func box(_ spot: NotepadRules.Spot, rower: NotepadViewModel.Rower) -> some View {
        let isSelected = viewModel.selection == spot
        let shown = shownCell(spot, isSelected: isSelected)
        let shape = RoundedRectangle(cornerRadius: Tokens.Notepad.cellRadius, style: .continuous)
        return Button {
            onSelect(spot)
        } label: {
            HStack(spacing: 3) {
                if case .posted = shown {
                    Circle()
                        .fill(Tokens.Accent.brand)
                        .frame(width: Tokens.Notepad.postedDot, height: Tokens.Notepad.postedDot)
                        .accessibilityHidden(true)
                }
                Text(Self.text(shown))
                    .textStyle(Self.hasValue(shown) ? Typography.rowTitle : Typography.detail)
                    .tabularNumerals()
                    .foregroundStyle(Self.hasValue(shown) ? Tokens.Ink.primary : Tokens.Ink.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: Tokens.Notepad.cellWidth - 4, height: Tokens.Notepad.cellHeight)
            .background(shape.fill(isSelected ? Tokens.Accent.brandSoft : Color.clear))
            .overlay {
                shape.strokeBorder(isSelected ? Tokens.Accent.brand : Color.clear, lineWidth: Tokens.Notepad.selectedBorder)
            }
            .frame(width: Tokens.Notepad.cellWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(accessibilityText(shown, rower: rower, rep: spot.rep))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The selected box shows what's being typed as soon as it reads as a split.
    private func shownCell(_ spot: NotepadRules.Spot, isSelected: Bool) -> NotepadRules.Cell {
        if isSelected, viewModel.hasTyped, let entry = viewModel.typedEntry { return .noted(splitMs: entry.splitMs) }
        return viewModel.cell(spot)
    }

    private static func text(_ cell: NotepadRules.Cell) -> String {
        switch cell {
        case .empty: "–"
        case .posted(let split), .noted(let split): WorkoutRules.splitTenthsText(split)
        case .satOut: "out"
        }
    }

    private static func hasValue(_ cell: NotepadRules.Cell) -> Bool {
        switch cell {
        case .posted, .noted: true
        case .empty, .satOut: false
        }
    }

    private func accessibilityText(_ cell: NotepadRules.Cell, rower: NotepadViewModel.Rower, rep: Int) -> String {
        let place = viewModel.reps.count > 1 ? "\(rower.name), piece \(rep + 1)" : rower.name
        switch cell {
        case .empty: return "\(place): empty"
        case .posted(let split): return "\(place): \(WorkoutRules.splitTenthsText(split)), from their own post"
        case .noted(let split): return "\(place): \(WorkoutRules.splitTenthsText(split))"
        case .satOut: return "\(place): sat out"
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Tokens.Accent.brand)
                .frame(width: Tokens.Notepad.postedDot, height: Tokens.Notepad.postedDot)
                .accessibilityHidden(true)
            Text("from their own post · tap a box to type")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .overlay(alignment: .top) { Divider().overlay(Tokens.Surface.cardEdge) }
    }
}

/// The page compares the card by its view model alone, so it isn't rebuilt every time the page is
/// (a key typed in Notes or a block, + Row). The card reads the view model itself, so @Observable
/// still redraws it whenever its rowers, selection or scores change. `onSelect` is left out: a
/// closure can't be compared, and the page's one always does the same thing.
extension NotepadScoresCard: Equatable {
    static func == (lhs: NotepadScoresCard, rhs: NotepadScoresCard) -> Bool {
        lhs.viewModel === rhs.viewModel
    }
}
