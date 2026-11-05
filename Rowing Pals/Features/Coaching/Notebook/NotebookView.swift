//
//  NotebookView.swift
//  Rowing Pals
//

import SwiftUI

/// The coach's Notebook, to the v4 CoachNotebook artboard (decision 96, NP4): one page per past
/// workout with a notepad or any scores, opening on the newest. A squad filter top right, **Splits |
/// Against target**, the page turned with the arrows or a sideways swipe, page dots, and each page's
/// rowers (tap a name for their line), the squad's averages, Notes, "6 posted · 4 you noted" and
/// **Edit page**. Workouts → Past → Notebook.
struct NotebookView: View {
    @State private var viewModel = NotebookViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate
    @State private var cardWidth: CGFloat = 0

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                PillSegmentedControl(
                    options: ["Splits", "Against target"],
                    selection: Binding(get: { viewModel.showsTarget ? 1 : 0 }, set: { viewModel.showsTarget = $0 == 1 })
                )
                if let page = viewModel.page {
                    pageCard(page)
                        .gesture(swipe)
                    if !page.notes.isEmpty { notes(page.notes) }
                    HStack {
                        Text(page.sourcesText)
                            .textStyle(Typography.meta)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                        Spacer(minLength: Tokens.Spacing.tight)
                        Button {
                            navigate(.notepad(page.workout.id))
                        } label: {
                            Label("Edit page", icon: .pencil, size: Tokens.Icon.small)
                        }
                        .buttonStyle(.rpText)
                    }
                    .padding(.horizontal, 4)
                    dots
                    Text("\(viewModel.pageLabel) · swipe to turn the page · tap a name to see their line")
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                } else if viewModel.hasLoaded {
                    Text("No pages yet. A workout gets a page here once its day is over and a rower has posted for it, or a coach has used its notepad.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Tokens.Spacing.group)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, Tokens.Spacing.group)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Notebook", onBack: { dismiss() }) { squadMenu }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Squad filter

    private var squadMenu: some View {
        Menu {
            Picker("Squad", selection: $viewModel.squadId) {
                Text("All squads").tag(UUID?.none)
                ForEach(viewModel.squads) { squad in
                    Text(squad.name).tag(UUID?.some(squad.id))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.squadName)
                    .lineLimit(1)
                RPIconView(icon: .chevronDown, size: Tokens.Icon.small)
            }
            .textStyle(Typography.pill)
            .foregroundStyle(Tokens.Ink.primary)
            .padding(.horizontal, Tokens.Spacing.loose)
            .frame(minHeight: Tokens.Size.iconButton)
            .glassSurface(in: Capsule())
        }
        .accessibilityLabel("Squad: \(viewModel.squadName)")
    }

    // MARK: - The page

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height), abs(dx) > Tokens.Notepad.pageSwipe else { return }
                withAnimation(Tokens.Motion.scrollToTop) { viewModel.turn(by: dx < 0 ? 1 : -1) }
            }
    }

    private func pageCard(_ page: NotebookRules.Page) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.Spacing.tight) {
                pageArrow(.chevronLeft, label: "Older page", enabled: viewModel.index > 0) { viewModel.turn(by: -1) }
                VStack(spacing: 2) {
                    Text(WorkoutRules.whenText(page.workout, calendar: .current))
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                    Text(page.workout.title)
                        .textStyle(Typography.coachStatSmall)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(subtitle(page))
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .tabularNumerals()
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                pageArrow(.chevronRight, label: "Newer page", enabled: viewModel.index < viewModel.pages.count - 1) { viewModel.turn(by: 1) }
            }
            .padding(Tokens.Spacing.loose)

            table(page)
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .clipShape(Self.cardShape)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardWidth = $0 }
    }

    /// "AT · target 1:42.0 · rate 26–28", or "Test · results on the club board".
    private func subtitle(_ page: NotebookRules.Page) -> String {
        if page.isTest { return "Test · results on the club board" }
        var parts: [String] = []
        if let zone = page.workout.zone { parts.append(zone) }
        if let split = page.workout.pieces.first?.splitMs { parts.append("target \(WorkoutRules.splitTenthsText(split))") }
        if let rate = WorkoutRules.rateText(page.workout.pieces) { parts.append("rate \(rate)") }
        return parts.isEmpty ? (page.workout.isTestDay ? "Test" : "Erg workout") : parts.joined(separator: " · ")
    }

    private func pageArrow(_ icon: RPIcon, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Tokens.Motion.scrollToTop) { action() }
        } label: {
            RPIconView(icon: icon, size: Tokens.Icon.small)
                .foregroundStyle(enabled ? Tokens.Ink.primary : Tokens.Ink.faint)
                .frame(width: Tokens.Notepad.pageArrow, height: Tokens.Notepad.pageArrow)
                .glassSurface(in: Circle())
                .frame(minWidth: Tokens.Size.minTap, minHeight: Tokens.Size.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: - The table

    private struct Cell {
        let text: String
        let color: Color
        let isBold: Bool
    }

    private func columns(_ page: NotebookRules.Page) -> [String] {
        if page.isTest { return [page.reps.first??.kind == .time ? "Metres" : "Time", "Split"] }
        return page.reps.indices.map { "\($0 + 1)" } + ["Avg"]
    }

    private func columnWidth(_ page: NotebookRules.Page) -> CGFloat {
        columns(page).count > 4 ? Tokens.Notepad.notebookColumnTight : Tokens.Notepad.notebookColumn
    }

    /// The values' width, capped so the names keep their least width; past that they scroll sideways.
    private func valuesWidth(_ page: NotebookRules.Page) -> CGFloat {
        let wanted = CGFloat(columns(page).count) * columnWidth(page)
        guard cardWidth > 0 else { return wanted }
        return min(wanted, max(0, cardWidth - Tokens.Spacing.card * 2 - Tokens.Notepad.notebookNameMin))
    }

    private func table(_ page: NotebookRules.Page) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header("Rower", alignment: .leading)
                ForEach(page.rows) { row in
                    Button {
                        navigate(.notebookRower(row.rowerId))
                    } label: {
                        Text(row.name)
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, minHeight: Tokens.Notepad.rowHeight - 1, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                    .overlay(alignment: .top) { line }
                    .accessibilityHint("Shows their line across the notebook")
                }
                Text("Squad")
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .frame(maxWidth: .infinity, minHeight: Tokens.Notepad.rowHeight - 1, alignment: .leading)
                    .overlay(alignment: .top) { line }
            }
            ScrollView(.horizontal) {
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(columns(page), id: \.self) { header($0, alignment: .trailing).frame(width: columnWidth(page), alignment: .trailing) }
                    }
                    ForEach(page.rows) { row in
                        values(cells(row, page: page), page: page)
                            .overlay(alignment: .top) { line }
                    }
                    values(squadCells(page), page: page, isSquad: true)
                        .overlay(alignment: .top) { line }
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(width: valuesWidth(page))
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.bottom, Tokens.Spacing.tight)
    }

    private var line: some View { Rectangle().fill(Tokens.Surface.cardEdge).frame(height: 1) }

    private func header(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .textStyle(Typography.tag)
            .foregroundStyle(Tokens.Ink.secondary)
            .frame(maxWidth: alignment == .leading ? .infinity : nil, minHeight: Tokens.Size.chip + 8, alignment: alignment)
    }

    private func values(_ cells: [Cell], page: NotebookRules.Page, isSquad: Bool = false) -> some View {
        let tight = columns(page).count > 4
        return HStack(spacing: 0) {
            ForEach(cells.indices, id: \.self) { index in
                let cell = cells[index]
                Text(cell.text)
                    .font(cellFont(tight: tight, bold: cell.isBold || isSquad))
                    .tabularNumerals()
                    .foregroundStyle(cell.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: columnWidth(page), alignment: .trailing)
            }
        }
        .frame(minHeight: Tokens.Notepad.rowHeight - 1)
    }

    private func cellFont(tight: Bool, bold: Bool) -> Font {
        let style = tight ? Typography.meta : Typography.detail
        return bold ? style.font.weight(.bold) : style.font
    }

    private func cells(_ row: NotebookRules.Row, page: NotebookRules.Page) -> [Cell] {
        if page.isTest {
            let isTimed = page.reps.first??.kind == .time
            let result = isTimed ? row.metres.map(NotepadRules.grouped) : row.timeMs.map(WorkoutRules.splitTenthsText)
            guard let result, let split = row.splits.first ?? nil else {
                return [Cell(text: "not yet", color: Tokens.Ink.faint, isBold: false), Cell(text: "–", color: Tokens.Ink.faint, isBold: false)]
            }
            return [Cell(text: result, color: Tokens.Ink.primary, isBold: true),
                    Cell(text: WorkoutRules.splitTenthsText(split), color: Tokens.Ink.secondary, isBold: false)]
        }
        if row.isAllSatOut {
            return row.splits.map { _ in Cell(text: "out", color: Tokens.Ink.faint, isBold: false) }
                + [Cell(text: "–", color: Tokens.Ink.faint, isBold: false)]
        }
        var result = row.splits.indices.map { rep in
            if row.satOut[rep] { return Cell(text: "out", color: Tokens.Ink.faint, isBold: false) }
            return value(row.splits[rep], target: row.targets[rep], bold: false)
        }
        result.append(value(row.average, target: row.averageTarget, bold: true))
        return result
    }

    private func squadCells(_ page: NotebookRules.Page) -> [Cell] {
        if page.isTest {
            let isTimed = page.reps.first??.kind == .time
            let metres = NotebookRules.Row.mean(page.rows.map(\.metres)).map(NotepadRules.grouped)
            let result = isTimed ? metres : page.squadTime.map(WorkoutRules.splitTenthsText)
            return [Cell(text: result ?? "–", color: result == nil ? Tokens.Ink.faint : Tokens.Ink.primary, isBold: true),
                    Cell(text: (page.squadSplits.first ?? nil).map(WorkoutRules.splitTenthsText) ?? "–", color: Tokens.Ink.secondary, isBold: false)]
        }
        if viewModel.showsTarget {
            return (page.squadDeltas + [page.squadAverageDelta]).map(deltaCell)
        }
        return (page.squadSplits + [page.squadAverage]).map { split in
            Cell(text: split.map(WorkoutRules.splitTenthsText) ?? "–", color: split == nil ? Tokens.Ink.faint : Tokens.Ink.primary, isBold: true)
        }
    }

    /// A split, or how far off the rower's target it was (green faster, red slower).
    private func value(_ split: Int?, target: Int?, bold: Bool) -> Cell {
        guard let split else { return Cell(text: "–", color: Tokens.Ink.faint, isBold: false) }
        if viewModel.showsTarget {
            guard let target else { return Cell(text: "–", color: Tokens.Ink.faint, isBold: false) }
            return deltaCell(split - target)
        }
        return Cell(text: WorkoutRules.splitTenthsText(split), color: Tokens.Ink.primary, isBold: bold)
    }

    private func deltaCell(_ delta: Int?) -> Cell {
        guard let delta else { return Cell(text: "–", color: Tokens.Ink.faint, isBold: false) }
        return Cell(text: NotebookRules.deltaText(delta), color: delta <= 0 ? Tokens.Accent.success : Tokens.System.error, isBold: true)
    }

    // MARK: - Notes and dots

    private func notes(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes")
                .textStyle(Typography.kicker)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(text)
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Ink.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .background(RoundedRectangle(cornerRadius: Tokens.Notepad.tableRadius, style: .continuous).fill(Tokens.Surface.card))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Notepad.tableRadius, style: .continuous)
                .strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1)
        }
    }

    private var dots: some View {
        HStack(spacing: Tokens.Notepad.pageDotGap) {
            ForEach(viewModel.pages.indices, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.index ? Tokens.Accent.brand : Tokens.Surface.line)
                    .frame(width: Tokens.Notepad.pageDot, height: Tokens.Notepad.pageDot)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.pageLabel)
    }
}
