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
            ScreenHeader(title: viewModel.isNew ? "New practice" : "Edit practice") { dismiss() }
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

    @ViewBuilder
    private var form: some View {
        FormLabel("What")
        TextField("Water, Erg, Circuits…", text: $viewModel.title)
            .textStyle(Typography.bodyV3)
            .padding(.horizontal, Tokens.Spacing.card)
            .formFieldBox()
        WrapLayout(spacing: Tokens.Spacing.tight) {
            ForEach(PracticeEditorViewModel.titles, id: \.self) { title in
                Button(title) { viewModel.title = title }
                    .buttonStyle(.rpPill(isOn: viewModel.title == title))
            }
        }
        .padding(.top, Tokens.Spacing.tight)

        FormLabel("Date").padding(.top, Tokens.Spacing.loose)
        DatePicker("Date", selection: $viewModel.day, displayedComponents: .date)
            .labelsHidden()
            .formFieldBox()
            .disabled(viewModel.isSeries)

        FormLabel("Place").padding(.top, Tokens.Spacing.loose)
        TextField("UEA boathouse", text: $viewModel.place)
            .textStyle(Typography.bodyV3)
            .padding(.horizontal, Tokens.Spacing.card)
            .formFieldBox()

        HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 0) {
                FormLabel("Starts")
                DatePicker("Starts", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .formFieldBox()
            }
            VStack(alignment: .leading, spacing: 0) {
                FormLabel("Ends")
                DatePicker("Ends", selection: $viewModel.endTime, in: viewModel.endRange, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .formFieldBox()
            }
        }
        .padding(.top, Tokens.Spacing.loose)

        FormSectionTitle("Squads")
        WrapLayout(spacing: Tokens.Spacing.tight) {
            Button("Whole club") { viewModel.squadIds = [] }
                .buttonStyle(.rpPill(isOn: viewModel.squadIds.isEmpty))
            ForEach(viewModel.squads) { squad in
                Button(squad.name) { viewModel.toggle(squad) }
                    .buttonStyle(.rpPill(isOn: viewModel.squadIds.contains(squad.id)))
            }
        }

        if viewModel.isNew || viewModel.isSeries {
            FormSectionTitle("Repeats")
            ToggleCard(title: "Every week", detail: viewModel.repeatDayText, isOn: $viewModel.repeats)
                // A series keeps its weeks; to end it early, cancel the rest of the series.
                .disabled(!viewModel.isNew)
            if viewModel.repeats {
                FormLabel("Until").padding(.top, Tokens.Spacing.loose)
                DatePicker("Until", selection: $viewModel.repeatUntil, in: viewModel.day..., displayedComponents: .date)
                    .labelsHidden()
                    .formFieldBox()
                    .disabled(!viewModel.isNew)
            }
            if viewModel.isSeries {
                FormFootnote("When you save, choose this practice only or the rest of the series. The day can only change for one practice at a time.")
            }
        }

        FormSectionTitle("Reminder")
        ToggleCard(title: "Remind rowers", detail: "2 hours before. Rowers can turn this off in Settings.", isOn: $viewModel.remind)

        FormFootnote(viewModel.isNew
            ? "\(viewModel.audienceCount) rower\(viewModel.audienceCount == 1 ? " is" : "s are") notified. Editing or cancelling this practice or its series notifies them again."
            : "Everyone it’s for is notified when you save or cancel it.")

        if let problem = viewModel.problem {
            Text(problem)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.loose)
        }
        if let error = viewModel.errorMessage {
            Text(error)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.loose)
        }

        Button {
            if viewModel.isSeries { isAskingScope = true } else { save(restOfSeries: false) }
        } label: {
            if viewModel.isSaving {
                ProgressView().tint(Tokens.Ink.onBrand)
            } else {
                Text("Save practice")
            }
        }
        .buttonStyle(.rpPrimary)
        .disabled(viewModel.isSaving || viewModel.problem != nil)
        .padding(.top, Tokens.Spacing.group)

        if !viewModel.isNew && viewModel.existing?.cancelled == false {
            Button("Cancel this practice") { cancelling = .one }
                .buttonStyle(.rpDestructive)
                .disabled(viewModel.isSaving)
                .padding(.top, Tokens.Spacing.tight)
            if viewModel.isSeries {
                Button("Cancel the whole series") { cancelling = .series }
                    .buttonStyle(.rpDestructive)
                    .disabled(viewModel.isSaving)
                    .padding(.top, Tokens.Spacing.tight)
            }
        }
    }

    private func save(restOfSeries: Bool) {
        Task { if await viewModel.save(restOfSeries: restOfSeries) { dismiss() } }
    }

    private func cancel(restOfSeries: Bool) {
        Task { if await viewModel.cancelPractice(restOfSeries: restOfSeries) { dismiss() } }
    }
}
