//
//  PracticeEditorView.swift
//  Rowing Pals
//

import SwiftUI

/// New practice or Edit practice (CoachPracticeNew; decisions 39, 68): what it is, the day, start
/// and end, the place, the squads it's for, every week until a day, and the reminder rowers can
/// turn off. Editing a practice in a series asks whether the change is for this one or the rest of
/// the series; Cancel this practice and Cancel the whole series sit at the bottom.
struct PracticeEditorView: View {
    @State private var viewModel: PracticeEditorViewModel
    @State private var isAskingScope = false
    /// Which cancel is waiting for its confirmation.
    @State private var cancelling: CancelScope?

    private enum CancelScope { case one, series }
    @Environment(\.dismiss) private var dismiss

    init(practiceId: UUID?, day: Date?) {
        _viewModel = State(initialValue: PracticeEditorViewModel(practiceId: practiceId, day: day))
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
            ScreenHeader(title: viewModel.isNew ? "New practice" : "Edit practice", onBack: { dismiss() }) {
                HeaderSaveButton(title: "Save", isSaving: viewModel.isSaving,
                                 isDisabled: !viewModel.hasLoaded || viewModel.problem != nil) { saveTapped() }
            }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
        .confirmationDialog("Save the change for", isPresented: $isAskingScope, titleVisibility: .visible) {
            Button("This practice only") { save(restOfSeries: false) }
            Button("This and the rest of the series") { save(restOfSeries: true) }
        } message: {
            Text("Each practice in the series keeps its own day.")
        }
        .alert(cancelling == .series ? "Cancel the whole series?" : "Cancel this practice?",
               isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } }),
               presenting: cancelling) { scope in
            Button(scope == .series ? "Cancel series" : "Cancel practice", role: .destructive) {
                cancel(restOfSeries: scope == .series)
            }
            Button("Keep it", role: .cancel) {}
        } message: { scope in
            Text(scope == .series
                 ? "This practice and every later one in the series come off the calendar. Everyone they’re for is notified."
                 : "It comes off the calendar. Everyone it’s for is notified.")
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.Grouped.groupGap) {
            GroupedSection {
                GroupedTextRow(label: "What", placeholder: "Water, Erg, Circuits…", text: $viewModel.title)
                GroupedDivider()
                GroupedChipsRow {
                    ForEach(PracticeEditorViewModel.titles, id: \.self) { title in
                        Button(title) { viewModel.title = title }
                            .buttonStyle(.rpPill(isOn: viewModel.title == title, minHeight: Tokens.Size.compactSegment))
                    }
                }
                GroupedDivider()
                GroupedTextRow(label: "Place", placeholder: "UEA boathouse", text: $viewModel.place)
            }

            GroupedSection {
                GroupedRow(label: "Date") {
                    DatePicker("Date", selection: $viewModel.day, displayedComponents: .date)
                        .labelsHidden()
                        .disabled(viewModel.isSeries)
                }
                GroupedDivider()
                GroupedRow(label: "Starts") {
                    DatePicker("Starts", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                GroupedDivider()
                GroupedRow(label: "Ends") {
                    DatePicker("Ends", selection: $viewModel.endTime, in: viewModel.endRange, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                if viewModel.isNew || viewModel.isSeries {
                    GroupedDivider()
                    GroupedToggleRow(label: "Every week", detail: viewModel.repeatDayText, isOn: $viewModel.repeats)
                        // A series keeps its weeks; to end it early, cancel the rest of the series.
                        .disabled(!viewModel.isNew)
                    if viewModel.repeats {
                        GroupedDivider()
                        GroupedRow(label: "Until") {
                            DatePicker("Until", selection: $viewModel.repeatUntil, in: viewModel.day..., displayedComponents: .date)
                                .labelsHidden()
                                .disabled(!viewModel.isNew)
                        }
                    }
                }
            }
            .groupedFooter(viewModel.isSeries
                ? "When you save, choose this practice only or the rest of the series. The day can only change for one practice at a time."
                : nil)

            GroupedSection(header: "Squads") {
                GroupedChipsRow {
                    Button("Whole club") { viewModel.squadIds = [] }
                        .buttonStyle(.rpPill(isOn: viewModel.squadIds.isEmpty, minHeight: Tokens.Size.compactSegment))
                    ForEach(viewModel.squads) { squad in
                        Button(squad.name) { viewModel.toggle(squad) }
                            .buttonStyle(.rpPill(isOn: viewModel.squadIds.contains(squad.id), minHeight: Tokens.Size.compactSegment))
                    }
                }
            }

            GroupedSection(footer: viewModel.isNew
                ? "\(viewModel.audienceCount) rower\(viewModel.audienceCount == 1 ? " is" : "s are") notified. Editing or cancelling this practice or its series notifies them again."
                : "Everyone it’s for is notified when you save or cancel it.") {
                GroupedToggleRow(label: "Remind rowers", detail: "2 hours before. Rowers can turn this off in Settings.",
                                 isOn: $viewModel.remind)
            }

            if let problem = viewModel.problem { GroupedError(text: problem) }
            if let error = viewModel.errorMessage { GroupedError(text: error) }

            if !viewModel.isNew && viewModel.existing?.cancelled == false {
                GroupedSection {
                    GroupedButtonRow(title: "Cancel this practice", isDestructive: true, isCentred: true) { cancelling = .one }
                    if viewModel.isSeries {
                        GroupedDivider()
                        GroupedButtonRow(title: "Cancel the whole series", isDestructive: true, isCentred: true) { cancelling = .series }
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
    }

    private func saveTapped() {
        if viewModel.isSeries { isAskingScope = true } else { save(restOfSeries: false) }
    }

    private func save(restOfSeries: Bool) {
        Task { if await viewModel.save(restOfSeries: restOfSeries) { dismiss() } }
    }

    private func cancel(restOfSeries: Bool) {
        Task { if await viewModel.cancelPractice(restOfSeries: restOfSeries) { dismiss() } }
    }
}
