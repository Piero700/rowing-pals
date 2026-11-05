//
//  NotepadView.swift
//  Rowing Pals
//

import SwiftUI

/// One set workout's notepad, to the v4 CoachNotepad artboard (decision 96): the workout, the
/// Scores table, the text boxes and tables a coach added, **Add text** / **Add table**, and Notes
/// at the bottom. Tapping a box opens the entry bar over the keyboard. Every coach in the club
/// sees and edits the same page; nothing on it counts for anyone's volume, pieces or PBs. Erg
/// order sits top right.
struct NotepadView: View {
    @State private var viewModel: NotepadViewModel
    @State private var isOrdering = false
    /// Many pieces: Summary (0) or Every piece (1), as on CoachNotepadPieces.
    @State private var piecesView = 0
    @FocusState private var focus: NotepadField?
    @Environment(\.dismiss) private var dismiss

    init(workoutId: UUID) {
        _viewModel = State(initialValue: NotepadViewModel(workoutId: workoutId))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                    if let workout = viewModel.workout {
                        summary(workout)
                        // `.equatable()`: typing in a block or Notes, or + Row / + Column, no longer
                        // rebuilds the whole Scores table along with the page. The table still
                        // redraws by itself whenever the scores it shows change (@Observable).
                        scoresBlock
                        ForEach($viewModel.blocks) { $block in
                            switch block.kind {
                            case .text:
                                NotepadTextBlockView(block: $block) { viewModel.remove(block.id) }
                            case .table:
                                NotepadTableBlockView(
                                    block: $block,
                                    onAddRow: { viewModel.addRow(to: block.id) },
                                    onAddColumn: { viewModel.addColumn(to: block.id) },
                                    onRemove: { viewModel.remove(block.id) }
                                )
                            }
                        }
                        addButtons
                        NotepadNotesSection(viewModel: viewModel)
                    } else if viewModel.isLoading || !viewModel.hasLoaded {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, Tokens.Spacing.group)
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
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.selection) { _, spot in
                guard let spot else {
                    focus = nil
                    return
                }
                withAnimation(Tokens.Motion.scrollToTop) { proxy.scrollTo(spot.rowerId, anchor: .center) }
                if focus == nil || focus == .rate {
                    focus = viewModel.mode == .metres ? .metres : .duration
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Notepad", onBack: leave) {
                if !viewModel.rowers.isEmpty {
                    GlassIconButton(icon: .sort, accessibilityLabel: "Erg order") { isOrdering = true }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.selection != nil {
                NotepadEntryBar(viewModel: viewModel, focus: $focus)
            }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        // Back from scanning a monitor: show the scores it filled in.
        .onAppear { if viewModel.hasLoaded { Task { await viewModel.load() } } }
        .refreshable { await viewModel.load() }
        .onChange(of: viewModel.blocks) { viewModel.pageChanged() }
        .onDisappear { Task { await viewModel.saveNow() } }
        .sheet(isPresented: $isOrdering) {
            ErgOrderSheet(viewModel: viewModel)
        }
    }

    private func leave() {
        Task { await viewModel.saveNow() }
        dismiss()
    }

    // MARK: - Parts

    /// The Scores block: a test's Time · Split · Rate; Summary | Every piece when the workout has
    /// more pieces than fit across; otherwise a box per piece (NP1, NP3).
    @ViewBuilder
    private var scoresBlock: some View {
        if viewModel.isTestPage {
            NotepadTestCard(viewModel: viewModel, onSelect: selectBox).equatable()
        } else if viewModel.hasManyPieces {
            PillSegmentedControl(options: ["Summary", "Every piece"], selection: $piecesView)
            if piecesView == 0 {
                NotepadSummaryCard(viewModel: viewModel, onSelect: selectBox).equatable()
            } else {
                NotepadScoresCard(viewModel: viewModel, isEveryPiece: true, onSelect: selectBox).equatable()
            }
        } else {
            NotepadScoresCard(viewModel: viewModel, onSelect: selectBox).equatable()
        }
    }

    private func selectBox(_ spot: NotepadRules.Spot) {
        viewModel.select(spot)
        focus = viewModel.mode == .metres ? .metres : .duration
    }

    private func summary(_ workout: CoachWorkout) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Tokens.Spacing.tight) {
                Text(workout.title)
                    .textStyle(Typography.profileName)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                // A test's page says so (CoachNotepadTest).
                if viewModel.test != nil { BrandChip(text: "Test") }
            }
            Text(summaryLine(workout))
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(.horizontal, 4)
    }

    /// "Tue 4 Nov · 17:30 · Senior men · rate 26–28".
    private func summaryLine(_ workout: CoachWorkout) -> String {
        var parts = [WorkoutRules.whenText(workout, calendar: .current)]
        if !viewModel.audienceText.isEmpty { parts.append(viewModel.audienceText) }
        if viewModel.isTestPage {
            parts.append(viewModel.rowers.count == 1 ? "1 rower" : "\(viewModel.rowers.count) rowers")
        } else {
            if let rest = WorkoutRules.restText(workout.pieces) { parts.append("rest \(rest)") }
            if let rate = WorkoutRules.rateText(workout.pieces) { parts.append("rate \(rate)") }
        }
        return parts.joined(separator: " · ")
    }

    private var addButtons: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            Button {
                viewModel.addText()
            } label: {
                Label("Add text", icon: .list, size: Tokens.Icon.small)
            }
            Button {
                viewModel.addTable()
            } label: {
                Label("Add table", icon: .clipboard, size: Tokens.Icon.small)
            }
        }
        .buttonStyle(.rpGlass)
        .disabled(!viewModel.canAddBlock)
    }

}
