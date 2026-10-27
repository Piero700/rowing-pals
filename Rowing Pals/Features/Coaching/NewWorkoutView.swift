//
//  NewWorkoutView.swift
//  Rowing Pals
//

import SwiftUI

/// New workout, to the v4 CoachWorkoutNew artboard (decision 39): title, date and an optional
/// time, a description, the target zone, pieces, test day, and who it's for — the whole club,
/// squads or rowers — with how many it reaches. Set workout tells them ("New workout from your
/// coach"); it shows on their Feed and Log screen on the day.
struct NewWorkoutView: View {
    @State private var viewModel = NewWorkoutViewModel()
    @State private var editingPiece: EditingPiece?
    @Environment(\.dismiss) private var dismiss

    init() {}

    /// New workout on a chosen day, from Add on the coach's Calendar.
    init(date: Date) {
        let viewModel = NewWorkoutViewModel()
        viewModel.date = date
        _viewModel = State(initialValue: viewModel)
    }

    private struct EditingPiece: Identifiable {
        let id = UUID()
        let piece: WorkoutPiece?
    }

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let fieldShape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                fieldLabel("Title")
                TextField("3 × 2,000m", text: $viewModel.title)
                    .textStyle(Typography.bodyV3)
                    .padding(.horizontal, Tokens.Spacing.card)
                    .frame(minHeight: Tokens.Size.input)
                    .background(Self.fieldShape.fill(Tokens.Surface.card))
                    .overlay { Self.fieldShape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }

                HStack(alignment: .top, spacing: Tokens.Spacing.loose) {
                    VStack(alignment: .leading, spacing: 0) {
                        fieldLabel("Date")
                        DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, minHeight: Tokens.Size.input)
                            .background(Self.fieldShape.fill(Tokens.Surface.card))
                            .overlay { Self.fieldShape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        fieldLabel("Time (optional)")
                        HStack(spacing: 0) {
                            if viewModel.hasTime {
                                DatePicker("Time", selection: $viewModel.time, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                Button {
                                    viewModel.hasTime = false
                                } label: {
                                    RPIconView(icon: .clear)
                                        .foregroundStyle(Tokens.Ink.secondary)
                                        .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                                }
                                .buttonStyle(IconPressStyle())
                                .accessibilityLabel("No set time")
                            } else {
                                Button("Add time") { viewModel.hasTime = true }
                                    .buttonStyle(.rpText)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(minHeight: Tokens.Size.input)
                        .background(Self.fieldShape.fill(Tokens.Surface.card))
                        .overlay { Self.fieldShape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
                    }
                }
                .padding(.top, Tokens.Spacing.loose)

                fieldLabel("Description")
                    .padding(.top, Tokens.Spacing.loose)
                TextField("What to do, and how it should feel", text: $viewModel.description, axis: .vertical)
                    .textStyle(Typography.bodyV3)
                    .lineLimit(3...8)
                    .padding(.horizontal, Tokens.Spacing.card)
                    .padding(.vertical, 14)
                    .frame(minHeight: Tokens.Size.input)
                    .background(Self.fieldShape.fill(Tokens.Surface.card))
                    .overlay { Self.fieldShape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }

                if !viewModel.isTestDay {
                    sectionTitle("Target zone")
                    PillSegmentedControl(
                        options: TrainingZone.allCases.map(\.rawValue),
                        selection: Binding(
                            get: { TrainingZone.allCases.firstIndex(of: viewModel.zone) ?? 0 },
                            set: { viewModel.zone = TrainingZone.allCases[$0] }
                        ),
                        compact: true
                    )
                }

                piecesSection
                testDaySection
                audienceSection

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }

                Button {
                    Task { if await viewModel.save() { dismiss() } }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(Tokens.Ink.onBrand)
                    } else {
                        Text("Set workout")
                    }
                }
                .buttonStyle(.rpPrimary)
                .disabled(viewModel.isSaving || viewModel.problem != nil)
                .padding(.top, Tokens.Spacing.group)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { header }
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
    }

    /// Cancel · New workout.
    private var header: some View {
        ZStack {
            HStack(spacing: 0) {
                GlassIconButton(icon: .close, accessibilityLabel: "Cancel") { dismiss() }
                Spacer(minLength: 0)
            }
            Text("New workout")
                .textStyle(Typography.navTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, Tokens.Spacing.tight)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, Tokens.Spacing.loose)
        .frame(minHeight: Tokens.Size.navHeight)
        .background(Tokens.Base.ground)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var piecesSection: some View {
        HStack(alignment: .firstTextBaseline) {
            sectionTitle("Pieces")
            Spacer(minLength: 0)
            Button("Add piece") { editingPiece = EditingPiece(piece: nil) }
                .buttonStyle(.rpText)
        }
        if !viewModel.pieces.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.pieces.enumerated()), id: \.element.id) { index, piece in
                    HStack(spacing: Tokens.Spacing.loose) {
                        Text("\(index + 1)")
                            .textStyle(Typography.pill)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.primary)
                            .frame(width: Tokens.Size.checkbox, height: Tokens.Size.checkbox)
                            .background(Circle().fill(Tokens.Surface.raised))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WorkoutRules.pieceTitle(piece))
                                .textStyle(Typography.rowTitle)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.primary)
                            Text(WorkoutRules.pieceDetail(piece) ?? "Each rower's own target split")
                                .textStyle(Typography.meta)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                        Spacer(minLength: 0)
                        RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                            .textStyle(Typography.pill)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .padding(.horizontal, Tokens.Spacing.card)
                    .padding(.vertical, Tokens.Spacing.loose)
                    .frame(minHeight: Tokens.Size.row)
                    .asButton { editingPiece = EditingPiece(piece: piece) }
                    .accessibilityElement(children: .combine)
                    if index < viewModel.pieces.count - 1 {
                        Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                    }
                }
            }
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .clipShape(Self.cardShape)
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        }
        footnote("Each piece can be a distance or a time, with reps, rest, target rate and target split.")
    }

    // MARK: - Test day

    @ViewBuilder
    private var testDaySection: some View {
        sectionTitle("Test day")
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This is a test")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text("Results go to the test’s leaderboard.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Test day", isOn: $viewModel.isTestDay)
                    .labelsHidden()
                    .tint(Tokens.Accent.brand)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .frame(minHeight: Tokens.Size.row)

            if viewModel.isTestDay {
                Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                Menu {
                    ForEach(viewModel.tests) { test in
                        Button(test.label) { viewModel.test = test }
                    }
                } label: {
                    HStack {
                        Text("Test")
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                        Spacer()
                        Text(viewModel.test?.label ?? "Choose")
                            .textStyle(Typography.detail)
                            .tabularNumerals()
                            .foregroundStyle(viewModel.test == nil ? Tokens.Accent.brand : Tokens.Ink.secondary)
                        RPIconView(icon: .chevronUpDown, size: Tokens.Icon.small)
                            .textStyle(Typography.pill)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .padding(.horizontal, Tokens.Spacing.card)
                    .frame(minHeight: Tokens.Size.rowCompact)
                    .contentShape(Rectangle())
                }
            }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .clipShape(Self.cardShape)
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    // MARK: - Who it's for

    @ViewBuilder
    private var audienceSection: some View {
        sectionTitle("Who it’s for")
        PillSegmentedControl(
            options: WorkoutAudience.allCases.map(\.label),
            selection: Binding(
                get: { WorkoutAudience.allCases.firstIndex(of: viewModel.audience) ?? 0 },
                set: { viewModel.audience = WorkoutAudience.allCases[$0] }
            ),
            compact: true
        )
        switch viewModel.audience {
        case .club:
            EmptyView()
        case .squads:
            if viewModel.squads.isEmpty {
                footnote("Your club has no squads yet. Make them in Squads, top right in Coaching.")
            } else {
                WrapLayout(spacing: Tokens.Spacing.tight) {
                    ForEach(viewModel.squads) { squad in
                        chip(squad.name, isOn: viewModel.squadIds.contains(squad.id)) {
                            viewModel.squadIds.formSymmetricDifference([squad.id])
                        }
                    }
                }
                .padding(.top, Tokens.Spacing.loose)
            }
        case .rowers:
            WrapLayout(spacing: Tokens.Spacing.tight) {
                ForEach(viewModel.rowers) { rower in
                    chip(rower.displayName, isOn: viewModel.rowerIds.contains(rower.id)) {
                        viewModel.rowerIds.formSymmetricDifference([rower.id])
                    }
                }
            }
            .padding(.top, Tokens.Spacing.loose)
        }
        let count = viewModel.recipientCount
        footnote("\(count) rower\(count == 1 ? "" : "s") get “New workout from your coach”. It shows on their Feed and Log screen on the day.")
            .padding(.top, 4)
    }

    private func chip(_ text: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(text) }
            .buttonStyle(.rpPill(isOn: isOn))
            .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Building blocks

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.group)
            .padding(.bottom, Tokens.Spacing.tight)
            .accessibilityAddTraits(.isHeader)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.meta)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.tight)
            .fixedSize(horizontal: false, vertical: true)
    }
}
