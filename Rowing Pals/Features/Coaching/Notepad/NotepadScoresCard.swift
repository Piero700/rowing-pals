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
    @Environment(\.navigate) private var navigate
    /// The names column's width, as laid out.
    @State private var namesWidth: CGFloat = 0

    /// The width left for the boxes after the names and the camera (worked out from the table's
    /// and the names' widths: a width read off the sideways scroll view itself doesn't follow it).
    private var boxesAreaWidth: CGFloat {
        max(0, tableWidth - namesWidth - Tokens.Notepad.scanColumn)
    }

    /// The table's whole width, names to boxes.
    @State private var tableWidth: CGFloat = 0

    /// Each box's width: an equal share of the space left, never under the smallest box.
    private var cellWidth: CGFloat {
        let count = CGFloat(max(viewModel.reps.count, 1))
        return max(Tokens.Notepad.cellWidth, (boxesAreaWidth / count).rounded(.down))
    }

    /// The most a name may take: what's left once every rep has its smallest box, so a long name is
    /// cut short ("Forgotpa…") rather than pushing a rep off the screen; never less than a short
    /// name needs, never more than the cap.
    private var nameMaxWidth: CGFloat {
        guard tableWidth > 0 else { return Tokens.Notepad.nameColumnMax }
        let boxes = CGFloat(max(viewModel.reps.count, 1)) * Tokens.Notepad.cellWidth
        let left = tableWidth - Tokens.Notepad.ergColumn - 4 - Tokens.Notepad.scanColumn - boxes
        return min(Tokens.Notepad.nameColumnMax, max(Tokens.Notepad.nameColumnMin, left.rounded(.down)))
    }

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
                // The names take only the width the longest one needs (up to a cap), the camera
                // sits right after them, and the boxes share whatever is left equally, so there's
                // no empty strip in the middle (user, 2026-11-05). With more reps than fit, each
                // box keeps its smallest width and the boxes scroll sideways.
                HStack(alignment: .top, spacing: 0) {
                    namesColumn
                        .fixedSize(horizontal: true, vertical: false)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { namesWidth = $0 }
                    scanColumn
                    ScrollView(.horizontal) {
                        boxesColumns
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .frame(maxWidth: .infinity)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { tableWidth = $0 }
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
                            .frame(maxWidth: nameMaxWidth, alignment: .leading)
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

    /// The camera button by each name (NP2): scan that rower's monitor into their row.
    private var scanColumn: some View {
        VStack(spacing: 0) {
            Color.clear.frame(width: Tokens.Notepad.scanColumn, height: Self.headerHeight)
            ForEach(viewModel.rowers) { rower in
                VStack(spacing: 0) {
                    Divider().overlay(Tokens.Surface.cardEdge)
                    Button {
                        navigate(.scanMonitor(viewModel.workoutId, rower.id))
                    } label: {
                        RPIconView(icon: .camera, size: Tokens.Icon.small)
                            .foregroundStyle(Tokens.Accent.brand)
                            .frame(width: Tokens.Notepad.scanButton, height: Tokens.Notepad.scanButton)
                            .glassSurface(in: Circle())
                            .frame(width: Tokens.Notepad.scanColumn, height: Tokens.Notepad.rowHeight - 1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                    .accessibilityLabel("Scan \(rower.name)’s monitor")
                }
            }
        }
        .frame(width: Tokens.Notepad.scanColumn)
    }

    private var boxesColumns: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(viewModel.reps.indices, id: \.self) { rep in
                    Text(viewModel.reps.count > 1 ? "\(rep + 1)" : "Score")
                        .textStyle(Typography.tag)
                        .tabularNumerals()
                        .foregroundStyle(viewModel.selection?.rep == rep ? Tokens.Accent.brand : Tokens.Ink.secondary)
                        .frame(width: cellWidth)
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
            .frame(width: cellWidth - 4, height: Tokens.Notepad.cellHeight)
            .background(shape.fill(isSelected ? Tokens.Accent.brandSoft : Color.clear))
            .overlay {
                shape.strokeBorder(isSelected ? Tokens.Accent.brand : Color.clear, lineWidth: Tokens.Notepad.selectedBorder)
            }
            .frame(width: cellWidth)
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
            Text("from their own post · tap a box to type · the camera reads their monitor")
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
