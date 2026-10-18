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
            ScreenHeader(title: viewModel.isNew ? "New erg event" : "Erg event") { dismiss() }
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

    @ViewBuilder
    private var form: some View {
        FormLabel("Name").padding(.top, Tokens.Spacing.card)
        TextField("Club 2k day", text: $viewModel.title)
            .textStyle(Typography.bodyV3)
            .padding(.horizontal, Tokens.Spacing.card)
            .formFieldBox()

        FormLabel("The piece").padding(.top, Tokens.Spacing.card)
        PillSegmentedControl(options: ["Distance", "Time"], selection: Binding(
            get: { viewModel.isDistance ? 0 : 1 },
            set: { viewModel.isDistance = $0 == 0 }
        ), compact: true)
        HStack {
            if viewModel.isDistance {
                TextField("2000", text: $viewModel.amount)
                    .keyboardType(.numberPad)
                    .focused($focused, equals: .distance)
                    .tabularNumerals()
                    .onChange(of: viewModel.amount) { viewModel.amount = String(viewModel.amount.filter(\.isNumber).prefix(6)) }
                Text("metres")
                    .foregroundStyle(Tokens.Ink.secondary)
            } else {
                DurationTextField(placeholder: "30:00", text: $viewModel.amount, focus: $focused, field: .time)
                    .tabularNumerals()
                Spacer(minLength: 0)
            }
        }
        .textStyle(Typography.bodyV3)
        .foregroundStyle(Tokens.Ink.primary)
        .padding(.horizontal, Tokens.Spacing.card)
        .formFieldBox()
        .padding(.top, Tokens.Spacing.tight)
        FormFootnote(viewModel.pieceLabel.map { "A \($0). The board ranks by \(viewModel.isDistance ? "fastest time" : "furthest distance")." }
                     ?? (viewModel.isDistance ? "A whole number of metres, e.g. 2000." : "Minutes and seconds, e.g. 30:00."))

        FormLabel("Starts").padding(.top, Tokens.Spacing.card)
        DatePicker("Starts", selection: $viewModel.startsAt, displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
            .formFieldBox()
        FormLabel("Ends").padding(.top, Tokens.Spacing.loose)
        DatePicker("Ends", selection: $viewModel.endsAt, in: viewModel.startsAt..., displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
            .formFieldBox()
        FormFootnote("A piece posted during it, or up to six hours after, can count — the rower turns on “Count for \(viewModel.title.isEmpty ? "this event" : viewModel.title)” when posting.")

        if let problem = viewModel.problem, !viewModel.title.isEmpty {
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
            Task { if await viewModel.save() { dismiss() } }
        } label: {
            if viewModel.isSaving {
                ProgressView().tint(Tokens.Ink.onBrand)
            } else {
                Text(viewModel.isNew ? "Set event" : "Save changes")
            }
        }
        .buttonStyle(.rpPrimary)
        .disabled(viewModel.isSaving || viewModel.problem != nil)
        .padding(.top, Tokens.Spacing.group)

        if !viewModel.isNew {
            Button("Delete event") { isConfirmingDelete = true }
                .buttonStyle(.rpDestructive)
                .disabled(viewModel.isSaving)
                .padding(.top, Tokens.Spacing.tight)
        }
        FormFootnote("Every rower in your club sees it in Rankings, and on their Feed on the day.")
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }
}
