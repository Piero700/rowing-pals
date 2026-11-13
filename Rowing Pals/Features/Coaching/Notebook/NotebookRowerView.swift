//
//  NotebookRowerView.swift
//  Rowing Pals
//

import SwiftUI

/// One rower's line across the Notebook, to the v4 CoachNotebookRower artboard (decision 96, NP4):
/// sessions done, their average against target and their fastest piece, then page by page (newest
/// first, today's session too) with the pieces, the average and how far off target it was. A line
/// opens its notepad page. Opened by tapping a name in the Notebook.
struct NotebookRowerView: View {
    let rowerId: UUID
    @State private var viewModel = NotebookViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    private var name: String { viewModel.fullNames[rowerId] ?? "Rower" }

    var body: some View {
        let lines = viewModel.lines(for: rowerId)
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                if viewModel.hasLoaded {
                    summaryCard(lines)
                    Text("Page by page")
                        .textStyle(Typography.sectionTitle)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.tight)
                        .accessibilityAddTraits(.isHeader)
                    if lines.isEmpty {
                        Text("Nothing for \(NotepadRules.shortName(name)) in the notebook yet.")
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.horizontal, 4)
                    } else {
                        linesCard(lines)
                        Text(footnote(lines))
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.horizontal, 4)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Tokens.Spacing.group)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, Tokens.Spacing.group)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: name) { dismiss() }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    /// "Averages are /500m. Tap a session to open its page. Today's session is still being written."
    private func footnote(_ lines: [NotebookRules.Line]) -> String {
        var text = "Averages are /500m. Tap a session to open its page."
        if lines.contains(where: \.isToday) { text += " Today’s session is still being written." }
        return text
    }

    private func summaryCard(_ lines: [NotebookRules.Line]) -> some View {
        let summary = NotebookRules.summary(lines)
        let pages = lines.filter { !$0.isToday }.count
        return VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            HStack(spacing: Tokens.Spacing.tight) {
                AvatarPlaceholder(diameter: Tokens.Notepad.scoresIcon, name: name, userId: rowerId)
                VStack(alignment: .leading, spacing: 1) {
                    Text("In the notebook")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text("\(viewModel.squadNames(of: rowerId)) · last \(pages) \(pages == 1 ? "page" : "pages")")
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            HStack(alignment: .top, spacing: Tokens.Spacing.tight) {
                stat("\(summary.done) of \(summary.of)", label: "sessions", color: Tokens.Ink.primary)
                stat(summary.averageDelta.map(NotebookRules.deltaText) ?? "–", label: "avg vs target",
                     color: summary.averageDelta.map { $0 <= 0 ? Tokens.Accent.success : Tokens.System.error } ?? Tokens.Ink.faint)
                stat(summary.fastestMs.map(WorkoutRules.splitTenthsText) ?? "–", label: "fastest piece", color: Tokens.Ink.primary)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    private func stat(_ value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .textStyle(Typography.coachStatSmall)
                .tabularNumerals()
                .foregroundStyle(color)
            Text(label)
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func linesCard(_ lines: [NotebookRules.Line]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                Button {
                    navigate(.notepad(line.page.workout.id))
                } label: {
                    lineRow(line)
                }
                .buttonStyle(IconPressStyle())
                .overlay(alignment: .top) {
                    if index > 0 { Rectangle().fill(Tokens.Surface.cardEdge).frame(height: 1) }
                }
            }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        .clipShape(Self.cardShape)
    }

    private func lineRow(_ line: NotebookRules.Line) -> some View {
        let row = line.row
        let delta = line.page.isTest ? nil : row.averageDelta
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Tokens.Spacing.tight) {
                Text(line.isToday ? "\(line.page.workout.title) · today" : line.page.workout.title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                Spacer(minLength: Tokens.Spacing.tight)
                Text(row.average.map(WorkoutRules.splitTenthsText) ?? "–")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(row.average == nil ? Tokens.Ink.faint : Tokens.Ink.primary)
                Text(delta.map(NotebookRules.deltaText) ?? "")
                    .textStyle(Typography.pill)
                    .foregroundStyle(delta.map { $0 <= 0 ? Tokens.Accent.success : Tokens.System.error } ?? Tokens.Ink.secondary)
                    .frame(minWidth: Tokens.Notepad.summaryFadeColumn, alignment: .trailing)
            }
            HStack(spacing: Tokens.Spacing.tight) {
                Text(dateLine(line))
                    .lineLimit(1)
                Spacer(minLength: Tokens.Spacing.tight)
                Text(piecesText(line))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
        }
        .tabularNumerals()
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens its notepad page")
    }

    /// "Tue 28 Oct · AT", or for a test "Sat 25 Oct · 17:41.0".
    private func dateLine(_ line: NotebookRules.Line) -> String {
        let day = WorkoutRules.whenText(line.page.workout, calendar: .current)
        if line.page.isTest {
            if let metres = line.row.metres, line.page.reps.first??.kind == .time { return "\(day) · \(NotepadRules.grouped(metres))m" }
            return line.row.timeMs.map { "\(day) · \(WorkoutRules.splitTenthsText($0))" } ?? day
        }
        return line.page.workout.zone.map { "\(day) · \($0)" } ?? day
    }

    /// "1:43.4 · 1:43.5 · –", or for a test where its result came from.
    private func piecesText(_ line: NotebookRules.Line) -> String {
        if line.page.isTest {
            switch line.row.origin {
            case .posted: return "from their post"
            case .noted: return "you noted"
            case .satOut: return "sat out"
            case .none: return "not yet"
            }
        }
        return line.row.splits.indices.map { rep in
            if line.row.satOut[rep] { return "out" }
            return line.row.splits[rep].map(WorkoutRules.splitTenthsText) ?? "–"
        }.joined(separator: " · ")
    }
}
