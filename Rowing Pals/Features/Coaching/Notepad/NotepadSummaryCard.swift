//
//  NotepadSummaryCard.swift
//  Rowing Pals
//

import SwiftUI

/// **Summary**, for a workout with more pieces than fit across (CoachNotepadPieces, decision 96,
/// NP3): one line per rower in erg order — pieces done, average and best split, and fade (the last
/// pieces against the first, red when 1.5 s or more slower). A name opens to every piece as tiles,
/// and a tile opens the entry bar for that piece.
struct NotepadSummaryCard: View {
    let viewModel: NotepadViewModel
    let onSelect: (NotepadRules.Spot) -> Void
    @Environment(\.navigate) private var navigate
    @State private var open: Set<UUID> = []

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let tileShape = RoundedRectangle(cornerRadius: Tokens.Notepad.cellRadius, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(viewModel.rowers) { rower in
                VStack(spacing: 0) {
                    Divider().overlay(Tokens.Surface.cardEdge)
                    line(rower)
                    if open.contains(rower.id) { tiles(rower) }
                }
                .id(rower.id)
            }
            Text(footnote)
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Spacing.card)
                .padding(.vertical, Tokens.Spacing.loose)
                .overlay(alignment: .top) { Divider().overlay(Tokens.Surface.cardEdge) }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .clipShape(Self.cardShape)
        .onChange(of: viewModel.selection) { _, spot in
            // A box picked by Next on a closed row opens it, so the coach sees where they are.
            if let spot { open.insert(spot.rowerId) }
        }
    }

    /// "Splits /500m. Fade is the last five pieces against the first five. Tap a name for every piece."
    private var footnote: String {
        let window = NotepadRules.fadeWindow(repCount: viewModel.reps.count)
        let count = window == 5 ? "five" : "\(window)"
        return "Splits /500m. Fade is the last \(count) pieces against the first \(count). Tap a name for every piece."
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("Rower").frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: Tokens.Notepad.scanButton)
            Text("Done").frame(width: Tokens.Notepad.summaryDoneColumn, alignment: .trailing)
            Text("Avg").frame(width: Tokens.Notepad.summaryValueColumn, alignment: .trailing)
            Text("Best").frame(width: Tokens.Notepad.summaryValueColumn, alignment: .trailing)
            Text("Fade").frame(width: Tokens.Notepad.summaryFadeColumn, alignment: .trailing)
        }
        .textStyle(Typography.tag)
        .foregroundStyle(Tokens.Ink.secondary)
        .padding(.leading, Tokens.Spacing.card)
        .padding(.trailing, Tokens.Spacing.gap)
        .padding(.top, Tokens.Spacing.loose)
        .padding(.bottom, 6)
    }

    private func line(_ rower: NotepadViewModel.Rower) -> some View {
        let summary = viewModel.summary(rower.id)
        let isOpen = open.contains(rower.id)
        return HStack(spacing: 4) {
            Button {
                if isOpen { open.remove(rower.id) } else { open.insert(rower.id) }
            } label: {
                HStack(spacing: 6) {
                    RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Text(rower.shortName)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        // A long name is cut short, never shrunk like the numbers beside it.
                        .minimumScaleFactor(1)
                }
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.minTap, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())
            .accessibilityLabel(rower.name)
            .accessibilityValue(isOpen ? "Showing every piece" : "")
            .accessibilityHint(isOpen ? "Hides the pieces" : "Shows every piece")

            ScanButton(rower: rower) { navigate(.scanMonitor(viewModel.workoutId, rower.id)) }

            Text("\(summary.done)/\(summary.total)")
                .textStyle(Typography.meta)
                .foregroundStyle(summary.done == summary.total ? Tokens.Ink.secondary : Tokens.Ink.primary)
                .frame(width: Tokens.Notepad.summaryDoneColumn, alignment: .trailing)
            Text(summary.averageMs.map(WorkoutRules.splitTenthsText) ?? "–")
                .textStyle(Typography.rowTitle)
                .foregroundStyle(summary.averageMs == nil ? Tokens.Ink.faint : Tokens.Ink.primary)
                .frame(width: Tokens.Notepad.summaryValueColumn, alignment: .trailing)
            Text(summary.bestMs.map(WorkoutRules.splitTenthsText) ?? "–")
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(width: Tokens.Notepad.summaryValueColumn, alignment: .trailing)
            Text(summary.fadeMs.map(NotepadRules.fadeText) ?? "–")
                .textStyle(Typography.pill)
                .foregroundStyle((summary.fadeMs ?? 0) >= NotepadRules.fadeWarningMs ? Tokens.System.error : Tokens.Ink.secondary)
                .frame(width: Tokens.Notepad.summaryFadeColumn, alignment: .trailing)
        }
        .tabularNumerals()
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.leading, Tokens.Spacing.card)
        .padding(.trailing, Tokens.Spacing.gap)
        .frame(minHeight: Tokens.Notepad.rowHeight - 1)
    }

    /// Every piece as a tile, five to a row; a tile opens the entry bar for it.
    private func tiles(_ rower: NotepadViewModel.Rower) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Notepad.tileGap), count: Tokens.Notepad.tilesPerRow)
        return LazyVGrid(columns: columns, spacing: Tokens.Notepad.tileGap) {
            ForEach(viewModel.reps.indices, id: \.self) { rep in
                tile(NotepadRules.Spot(rowerId: rower.id, rep: rep), rower: rower)
            }
        }
        .padding(.horizontal, Tokens.Spacing.loose)
        .padding(.top, 4)
        .padding(.bottom, Tokens.Spacing.card)
    }

    private func tile(_ spot: NotepadRules.Spot, rower: NotepadViewModel.Rower) -> some View {
        let isSelected = viewModel.selection == spot
        let cell = viewModel.cell(spot)
        let value: String = {
            if let metres = viewModel.metres(spot) { return NotepadRules.grouped(metres) }
            switch cell {
            case .empty: return "–"
            case .satOut: return "out"
            case .posted(let split), .noted(let split): return WorkoutRules.splitTenthsText(split)
            }
        }()
        let hasValue = viewModel.splitMs(spot) != nil
        return Button {
            onSelect(spot)
        } label: {
            VStack(spacing: 0) {
                Text("\(spot.rep + 1)")
                    .textStyle(Typography.navLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
                HStack(spacing: 3) {
                    if case .posted = cell {
                        Circle()
                            .fill(Tokens.Accent.brand)
                            .frame(width: Tokens.Notepad.postedDot, height: Tokens.Notepad.postedDot)
                            .accessibilityHidden(true)
                    }
                    Text(value)
                        .textStyle(Typography.pill)
                        .foregroundStyle(hasValue ? Tokens.Ink.primary : Tokens.Ink.faint)
                }
            }
            .tabularNumerals()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: Tokens.Notepad.tileHeight)
            .background(Self.tileShape.fill(isSelected ? Tokens.Accent.brandSoft : Tokens.Surface.raised))
            .overlay { Self.tileShape.strokeBorder(isSelected ? Tokens.Accent.brand : Color.clear, lineWidth: Tokens.Notepad.selectedBorder) }
            .contentShape(Self.tileShape)
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel("\(rower.name), piece \(spot.rep + 1): \(value == "–" ? "empty" : value)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Compared by its view model alone, like the Scores table: @Observable redraws it when its scores
/// change, and typing elsewhere on the page doesn't rebuild it.
extension NotepadSummaryCard: Equatable {
    static func == (lhs: NotepadSummaryCard, rhs: NotepadSummaryCard) -> Bool {
        lhs.viewModel === rhs.viewModel
    }
}

/// The round camera button by a name on the notepad (NP2): scan that rower's monitor.
struct ScanButton: View {
    let rower: NotepadViewModel.Rower
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RPIconView(icon: .camera, size: Tokens.Icon.small)
                .foregroundStyle(Tokens.Accent.brand)
                .frame(width: Tokens.Notepad.scanButton, height: Tokens.Notepad.scanButton)
                .glassSurface(in: Circle())
                .frame(minWidth: Tokens.Notepad.scanButton, minHeight: Tokens.Size.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel("Scan \(rower.name)’s monitor")
    }
}
