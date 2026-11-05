//
//  NewWorkoutView.swift
//  Rowing Pals
//

import SwiftUI

/// Setting or editing a land session (CoachWorkoutNew, decision 39), in the compact grouped-rows
/// style (user, 2026-11-05): the pieces first, since they decide the reps; then the title, date,
/// time, zone and who it's for; then test day and notes. The title is written from the pieces
/// unless the coach types their own. **Set** (or **Save** when editing) sits top right. Setting
/// tells the rowers ("New workout from your coach"); saving changes doesn't tell them again.
struct NewWorkoutView: View {
    @State private var viewModel: NewWorkoutViewModel
    @State private var editingPiece: EditingPiece?
    @State private var choosing: WorkoutAudience?
    @Environment(\.dismiss) private var dismiss

    init() {
        _viewModel = State(initialValue: NewWorkoutViewModel())
    }

    /// New workout on a chosen day, from Add on the coach's Calendar.
    init(date: Date) {
        let viewModel = NewWorkoutViewModel()
        viewModel.date = date
        _viewModel = State(initialValue: viewModel)
    }

    /// Editing a workout already set, from Edit on its results.
    init(editing workoutId: UUID) {
        _viewModel = State(initialValue: NewWorkoutViewModel(editing: workoutId))
    }

    private struct EditingPiece: Identifiable {
        let id = UUID()
        let piece: WorkoutPiece?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Grouped.groupGap) {
                piecesSection
                detailsSection
                extrasSection
                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, Tokens.Grouped.rowPadding)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, Tokens.Spacing.tabScrollBottom)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: viewModel.isEditing ? "Edit land session" : "New land session",
                         onBack: { dismiss() }) {
                setButton
            }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
        .sheet(item: $editingPiece) { editing in
            PieceEditorSheet(
                piece: editing.piece,
                onSave: { piece in
                    if let index = viewModel.pieces.firstIndex(where: { $0.id == piece.id }) {
                        viewModel.pieces[index] = piece
                    } else {
                        viewModel.pieces.append(piece)
                    }
                },
                onDelete: editing.piece.map { original in
                    { viewModel.pieces.removeAll { $0.id == original.id } }
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $choosing) { audience in
            chooseSheet(audience)
                .presentationDetents([.medium, .large])
        }
    }

    /// Set (new) or Save (editing), top right; greyed out until the form can be saved.
    private var setButton: some View {
        Button {
            Task { if await viewModel.save() { dismiss() } }
        } label: {
            if viewModel.isSaving {
                ProgressView()
            } else {
                Text(viewModel.isEditing ? "Save" : "Set")
            }
        }
        .buttonStyle(.rpText)
        .disabled(viewModel.isSaving || viewModel.problem != nil)
        .frame(minWidth: Tokens.Size.minTap, minHeight: Tokens.Size.minTap)
    }

    // MARK: - Pieces

    private var piecesSection: some View {
        GroupedSection(
            header: "Pieces",
            footer: viewModel.pieces.isEmpty ? "Each piece is a column on the notepad and the results." : nil
        ) {
            ForEach(viewModel.pieces) { piece in
                Button {
                    editingPiece = EditingPiece(piece: piece)
                } label: {
                    HStack(spacing: Tokens.Spacing.tight) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(WorkoutRules.pieceTitle(piece))
                                .textStyle(Typography.rowTitle)
                                .foregroundStyle(Tokens.Ink.primary)
                            Text(WorkoutRules.pieceDetail(piece) ?? "Each rower's own target split")
                                .textStyle(Typography.statLabel)
                                .foregroundStyle(Tokens.Ink.secondary)
                                .lineLimit(1)
                        }
                        .tabularNumerals()
                        Spacer(minLength: Tokens.Spacing.tight)
                        RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                            .foregroundStyle(Tokens.Ink.faint)
                    }
                    .padding(.horizontal, Tokens.Grouped.rowPadding)
                    .padding(.vertical, Tokens.Spacing.tight)
                    .frame(minHeight: Tokens.Grouped.rowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
                GroupedDivider()
            }
            Button {
                editingPiece = EditingPiece(piece: nil)
            } label: {
                HStack(spacing: Tokens.Spacing.tight) {
                    RPIconView(icon: .plus, size: Tokens.Icon.small)
                    Text("Add piece")
                    Spacer(minLength: 0)
                }
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Accent.brand)
                .padding(.horizontal, Tokens.Grouped.rowPadding)
                .frame(minHeight: Tokens.Grouped.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())
        }
    }

    // MARK: - Title, when, zone, who

    private var detailsSection: some View {
        let count = viewModel.recipientCount
        return GroupedSection(
            footer: viewModel.isEditing
                ? "Saving changes doesn't alert anyone again."
                : "\(count) rower\(count == 1 ? "" : "s") get “New workout from your coach”."
        ) {
            GroupedRow(label: "Title") {
                TextField(viewModel.autoTitle.isEmpty ? "From the pieces" : viewModel.autoTitle,
                          text: $viewModel.customTitle)
                    .textStyle(Typography.detail)
                    .tabularNumerals()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Tokens.Ink.primary)
            }
            GroupedDivider()
            GroupedRow(label: "Date") {
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                    .labelsHidden()
            }
            GroupedDivider()
            GroupedRow(label: "Time") {
                if viewModel.hasTime {
                    DatePicker("Time", selection: $viewModel.time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Button {
                        viewModel.hasTime = false
                    } label: {
                        RPIconView(icon: .clear, size: Tokens.Icon.small)
                            .foregroundStyle(Tokens.Ink.faint)
                            .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                    .accessibilityLabel("No set time")
                } else {
                    Button("Add") { viewModel.hasTime = true }
                        .textStyle(Typography.detail)
                        .foregroundStyle(Tokens.Accent.brand)
                }
            }
            if !viewModel.isTestDay {
                GroupedDivider()
                GroupedRow(label: "Zone") {
                    Menu {
                        Picker("Zone", selection: $viewModel.zone) {
                            ForEach(TrainingZone.allCases, id: \.self) { zone in Text(zone.rawValue).tag(zone) }
                        }
                    } label: {
                        GroupedValue(text: viewModel.zone.rawValue)
                    }
                }
            }
            GroupedDivider()
            GroupedRow(label: "For") {
                Menu {
                    Picker("For", selection: $viewModel.audience) {
                        ForEach(WorkoutAudience.allCases) { audience in Text(audience.label).tag(audience) }
                    }
                } label: {
                    GroupedValue(text: viewModel.audience.label)
                }
            }
            if viewModel.audience != .club {
                GroupedDivider()
                Button {
                    choosing = viewModel.audience
                } label: {
                    GroupedRow(label: viewModel.audience == .squads ? "Squads" : "Rowers") {
                        GroupedValue(text: viewModel.audienceText,
                                     isPlaceholder: viewModel.audienceText.hasPrefix("Choose"))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
            }
        }
    }

    // MARK: - Test day and notes

    private var extrasSection: some View {
        GroupedSection {
            GroupedRow(label: "Test day") {
                Toggle("Test day", isOn: $viewModel.isTestDay)
                    .labelsHidden()
                    .tint(Tokens.Accent.brand)
            }
            if viewModel.isTestDay {
                GroupedDivider()
                GroupedRow(label: "Test") {
                    Menu {
                        ForEach(viewModel.tests) { test in
                            Button(test.label) { viewModel.test = test }
                        }
                    } label: {
                        GroupedValue(text: viewModel.test?.label ?? "Choose", isPlaceholder: viewModel.test == nil)
                    }
                }
            }
            GroupedDivider()
            TextField("Notes for rowers", text: $viewModel.description, axis: .vertical)
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1...6)
                .padding(.horizontal, Tokens.Grouped.rowPadding)
                .padding(.vertical, Tokens.Spacing.loose)
                .frame(minHeight: Tokens.Grouped.rowHeight, alignment: .leading)
        }
    }

    // MARK: - Choosing squads or rowers

    private func chooseSheet(_ audience: WorkoutAudience) -> some View {
        let items: [(id: UUID, name: String)] = audience == .squads
            ? viewModel.squads.map { ($0.id, $0.name) }
            : viewModel.rowers.map { ($0.id, $0.displayName) }
        return NavigationStack {
            ScrollView {
                GroupedSection(footer: audience == .squads && items.isEmpty
                               ? "Your club has no squads yet. Make them in Squads, in Coaching." : nil) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let isOn = audience == .squads
                            ? viewModel.squadIds.contains(item.id)
                            : viewModel.rowerIds.contains(item.id)
                        Button {
                            if audience == .squads {
                                viewModel.squadIds.formSymmetricDifference([item.id])
                            } else {
                                viewModel.rowerIds.formSymmetricDifference([item.id])
                            }
                        } label: {
                            GroupedRow(label: item.name) {
                                if isOn {
                                    RPIconView(icon: .check, size: Tokens.Icon.small)
                                        .foregroundStyle(Tokens.Accent.brand)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IconPressStyle())
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        if index < items.count - 1 { GroupedDivider() }
                    }
                }
                .padding(Tokens.Spacing.screen)
            }
            .background(Tokens.Base.ground)
            .navigationTitle(audience == .squads ? "Squads" : "Rowers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { choosing = nil }
                }
            }
        }
    }
}
