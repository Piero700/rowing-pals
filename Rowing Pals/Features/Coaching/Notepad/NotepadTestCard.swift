//
//  NotepadTestCard.swift
//  Rowing Pals
//

import SwiftUI

/// A test's Scores block (CoachNotepadTest, decision 96, NP3): one line per rower — Time (metres for
/// a timed test), Split and Rate. A name opens to the 500m splits, from the rower's own post or a
/// scan of the monitor, with where they came from; a typed time says to scan for splits. Tapping
/// the time opens the entry bar. The footer says the club's test board only takes rowers' own posts.
struct NotepadTestCard: View {
    let viewModel: NotepadViewModel
    let onSelect: (NotepadRules.Spot) -> Void
    @Environment(\.navigate) private var navigate
    @State private var open: Set<UUID> = []

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let tileShape = RoundedRectangle(cornerRadius: Tokens.Notepad.cellRadius, style: .continuous)

    private var piece: WorkoutPiece? { viewModel.reps.first ?? nil }
    private var isTimed: Bool { piece?.kind == .time }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(viewModel.rowers) { rower in
                let line = viewModel.testLine(rower.id)
                VStack(alignment: .leading, spacing: 0) {
                    Divider().overlay(Tokens.Surface.cardEdge)
                    row(rower, line: line)
                    if open.contains(rower.id), line.source != .none { details(line) }
                }
                .id(rower.id)
            }
            footer
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        .clipShape(Self.cardShape)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("Rower").frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: Tokens.Notepad.scanButton)
            Text(isTimed ? "Metres" : "Time").frame(width: Tokens.Notepad.testTimeColumn, alignment: .trailing)
            Text("Split").frame(width: Tokens.Notepad.testSplitColumn, alignment: .trailing)
            Text("Rate").frame(width: Tokens.Notepad.testRateColumn, alignment: .trailing)
        }
        .textStyle(Typography.tag)
        .foregroundStyle(Tokens.Ink.secondary)
        .padding(.leading, Tokens.Spacing.card)
        .padding(.trailing, Tokens.Spacing.gap)
        .padding(.top, Tokens.Spacing.loose)
        .padding(.bottom, 6)
    }

    private func row(_ rower: NotepadViewModel.Rower, line: NotepadViewModel.TestLine) -> some View {
        let isOpen = open.contains(rower.id)
        let spot = NotepadRules.Spot(rowerId: rower.id, rep: 0)
        let isSelected = viewModel.selection == spot
        let canOpen = line.source != .none
        return HStack(spacing: 4) {
            Button {
                guard canOpen else { return onSelect(spot) }
                if isOpen { open.remove(rower.id) } else { open.insert(rower.id) }
            } label: {
                HStack(spacing: 6) {
                    RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                        .foregroundStyle(canOpen ? Tokens.Ink.secondary : Tokens.Ink.faint)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Text(rower.name)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.minTap, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())
            .accessibilityLabel(rower.name)
            .accessibilityHint(canOpen ? (isOpen ? "Hides the splits" : "Shows the 500m splits") : "Type their result")

            ScanButton(rower: rower) { navigate(.scanMonitor(viewModel.workoutId, rower.id)) }

            Button {
                onSelect(spot)
            } label: {
                HStack(spacing: 4) {
                    if line.isPosted {
                        Circle()
                            .fill(Tokens.Accent.brand)
                            .frame(width: Tokens.Notepad.postedDot, height: Tokens.Notepad.postedDot)
                            .accessibilityHidden(true)
                    }
                    Text(shownResult(line, isSelected: isSelected))
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(line.source == .none && !isSelected ? Tokens.Ink.faint : Tokens.Ink.primary)
                }
                .frame(width: Tokens.Notepad.testTimeColumn - 2, height: Tokens.Notepad.cellHeight, alignment: .trailing)
                .padding(.trailing, 2)
                .background(RoundedRectangle(cornerRadius: Tokens.Notepad.cellRadius, style: .continuous)
                    .fill(isSelected ? Tokens.Accent.brandSoft : Color.clear))
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Notepad.cellRadius, style: .continuous)
                        .strokeBorder(isSelected ? Tokens.Accent.brand : Color.clear, lineWidth: Tokens.Notepad.selectedBorder)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())
            .accessibilityLabel("\(rower.name): \(line.source == .none ? "no result" : line.result)")
            .accessibilityHint("Type their result")

            Text(line.split)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(width: Tokens.Notepad.testSplitColumn, alignment: .trailing)
            Text(line.rate)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(width: Tokens.Notepad.testRateColumn, alignment: .trailing)
        }
        .tabularNumerals()
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.leading, Tokens.Spacing.card)
        .padding(.trailing, Tokens.Spacing.gap)
        .frame(minHeight: Tokens.Notepad.rowHeight - 1)
    }

    /// What's being typed shows in the box as it reads.
    private func shownResult(_ line: NotepadViewModel.TestLine, isSelected: Bool) -> String {
        guard isSelected, viewModel.hasTyped, let entry = viewModel.typedEntry else { return line.result }
        if isTimed { return entry.distanceM.map(NotepadRules.grouped) ?? line.result }
        return WorkoutRules.splitTenthsText(entry.timeMs ?? NotepadRules.time(splitMs: entry.splitMs, piece: piece) ?? entry.splitMs)
    }

    /// The 500m splits as tiles, and where they came from.
    @ViewBuilder
    private func details(_ line: NotepadViewModel.TestLine) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !line.splits.isEmpty {
                let labels = NotepadRules.splitLabels(count: line.splits.count, piece: piece)
                let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Notepad.tileGap),
                                    count: min(line.splits.count, Tokens.Notepad.tilesPerRow))
                LazyVGrid(columns: columns, spacing: Tokens.Notepad.tileGap) {
                    ForEach(line.splits.indices, id: \.self) { index in
                        VStack(spacing: 0) {
                            Text(labels.indices.contains(index) ? labels[index] : "\(index + 1)")
                                .textStyle(Typography.navLabel)
                                .foregroundStyle(Tokens.Ink.secondary)
                            Text(WorkoutRules.splitTenthsText(line.splits[index]))
                                .textStyle(Typography.pill)
                                .foregroundStyle(Tokens.Ink.primary)
                        }
                        .tabularNumerals()
                        .frame(maxWidth: .infinity, minHeight: Tokens.Notepad.tileHeight)
                        .background(Self.tileShape.fill(Tokens.Surface.raised))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Text(sourceText(line))
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.top, 2)
        .padding(.bottom, Tokens.Spacing.card)
    }

    /// "500m splits from their own post." and the like.
    private func sourceText(_ line: NotepadViewModel.TestLine) -> String {
        let splits = splitsName(count: line.splits.count)
        switch line.source {
        case .post:
            return line.splits.isEmpty
                ? "Their post doesn’t have 500m splits: it was posted before they were kept, or typed in."
                : "\(splits.capitalizedFirst) from their own post."
        case .scanned:
            return line.splits.isEmpty
                ? "Read from the monitor without its splits. Scan the screen that lists them to add them."
                : "\(splits.capitalizedFirst) read from the monitor. The photo wasn’t kept."
        case .typed:
            return isTimed
                ? "You typed the metres. Scan the monitor to add the splits."
                : "You typed the time. Scan the monitor to add 500m splits."
        case .none:
            return ""
        }
    }

    /// "500m splits" for a piece split every 500m (a 2k's four), "splits" otherwise (a 5k's 1,000m rows).
    private func splitsName(count: Int) -> String {
        guard let piece, piece.kind == .distance, count > 0, piece.value / count == 500 else { return "splits" }
        return "500m splits"
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(Tokens.Accent.brand)
                .frame(width: Tokens.Notepad.postedDot, height: Tokens.Notepad.postedDot)
                .accessibilityHidden(true)
            Text("from their own post. The club’s \(viewModel.test?.label ?? "test") board only takes rowers’ own posts; numbers you scan or type stay on this page.")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .overlay(alignment: .top) { Divider().overlay(Tokens.Surface.cardEdge) }
    }
}

/// Compared by its view model alone, like the Scores table.
extension NotepadTestCard: Equatable {
    static func == (lhs: NotepadTestCard, rhs: NotepadTestCard) -> Bool {
        lhs.viewModel === rhs.viewModel
    }
}

private extension String {
    /// "500m splits" → "500m splits"; "splits" → "Splits".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
