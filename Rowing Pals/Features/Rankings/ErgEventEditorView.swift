//
//  ErgEventEditorView.swift
//  Rowing Pals
//

import SwiftUI

/// New erg event, or one to change (decision 91): Name, the piece (Distance or Time, as a club test
/// is set), Starts and Ends, then Set event or Save changes; editing adds Delete.
struct ErgEventEditorView: View {
    private enum Field: Hashable { case distance, time }

    @State private var viewModel: ErgEventEditorViewModel
    @State private var isConfirmingDelete = false
    @FocusState private var focused: Field?
    @Environment(\.dismiss) private var dismiss

    init(eventId: UUID?) {
        _viewModel = State(initialValue: ErgEventEditorViewModel(eventId: eventId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.hasLoaded {
                    form
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: viewModel.isNew ? "New erg event" : "Erg event", onBack: { dismiss() }) {
                HeaderSaveButton(title: viewModel.isNew ? "Set" : "Save", isSaving: viewModel.isSaving,
                                 isDisabled: !viewModel.hasLoaded || viewModel.problem != nil) {
                    Task { if await viewModel.save() { dismiss() } }
                }
            }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
        .alert("Delete this event?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its board goes. The pieces stay on everyone’s profile and Feed.")
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.Grouped.groupGap) {
            GroupedSection {
                GroupedTextRow(label: "Name", placeholder: "Club 2k day", text: $viewModel.title)
            }

            VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                PillSegmentedControl(options: ["Distance", "Time"], selection: Binding(
                    get: { viewModel.isDistance ? 0 : 1 },
                    set: { viewModel.isDistance = $0 == 0 }
                ), compact: true)
                GroupedSection(footer: viewModel.pieceLabel.map { "A \($0). The board ranks by \(viewModel.isDistance ? "fastest time" : "furthest distance")." }
                               ?? (viewModel.isDistance ? "A whole number of metres, e.g. 2000." : "Minutes and seconds, e.g. 30:00.")) {
                    GroupedRow(label: viewModel.isDistance ? "Distance" : "Time") {
                        if viewModel.isDistance {
                            TextField("2000", text: $viewModel.amount)
                                .keyboardType(.numberPad)
                                .focused($focused, equals: .distance)
                                .multilineTextAlignment(.trailing)
                                .textStyle(Typography.detail)
                                .tabularNumerals()
                                .onChange(of: viewModel.amount) { viewModel.amount = String(viewModel.amount.filter(\.isNumber).prefix(6)) }
                            Text("m")
                                .textStyle(Typography.detail)
                                .foregroundStyle(Tokens.Ink.secondary)
                        } else {
                            DurationTextField(placeholder: "30:00", text: $viewModel.amount, focus: $focused, field: .time,
                                              alignment: .trailing)
                                .textStyle(Typography.detail)
                                .tabularNumerals()
                                .frame(width: Tokens.Grouped.valueWidth, height: Tokens.Grouped.rowHeight)
                        }
                    }
                }
            }

            GroupedSection(footer: "A piece posted during it, or up to six hours after, can count — the rower turns on “Count for \(viewModel.title.isEmpty ? "this event" : viewModel.title)” when posting.") {
                GroupedRow(label: "Starts") {
                    DatePicker("Starts", selection: $viewModel.startsAt, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                GroupedDivider()
                GroupedRow(label: "Ends") {
                    DatePicker("Ends", selection: $viewModel.endsAt, in: viewModel.startsAt..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }

            if let problem = viewModel.problem, !viewModel.title.isEmpty { GroupedError(text: problem) }
            if let error = viewModel.errorMessage { GroupedError(text: error) }

            if viewModel.isNew {
                GroupedNote(text: "Every rower in your club sees it in Rankings, and on their Feed on the day.")
            } else {
                GroupedSection(footer: "Every rower in your club sees it in Rankings, and on their Feed on the day.") {
                    GroupedButtonRow(title: "Delete event", isDestructive: true, isCentred: true) { isConfirmingDelete = true }
                        .disabled(viewModel.isSaving)
                }
            }
        }
        .padding(.top, Tokens.Spacing.tight)
    }
}
