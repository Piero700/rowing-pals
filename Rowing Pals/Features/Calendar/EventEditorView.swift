//
//  EventEditorView.swift
//  Rowing Pals
//

import SwiftUI

/// New race or event, or Edit (CoachRaceNew; decision 68): Race or regatta · Other event, Name,
/// First day and Last day (Same day until changed), Place, Squads, Note, Ask who can race, and
/// Add to calendar. Editing adds Delete.
struct EventEditorView: View {
    @State private var viewModel: EventEditorViewModel
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.closeRoute) private var closeRoute

    init(eventId: UUID?, kind: EventKind = .race, day: Date? = nil) {
        _viewModel = State(initialValue: EventEditorViewModel(eventId: eventId, kind: kind, day: day))
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
            ScreenHeader(title: viewModel.isNew ? "New race or event" : (viewModel.isRace ? "Edit race" : "Edit event")) { dismiss() }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
        .alert("Delete \(viewModel.name.isEmpty ? "this" : viewModel.name)?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                // The race's own page is underneath; close the whole area.
                Task { if await viewModel.delete() { closeRoute() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It comes off everyone’s calendar, with every answer to it.")
        }
    }

    @ViewBuilder
    private var form: some View {
        PillSegmentedControl(
            options: EventKind.allCases.map(\.label),
            selection: Binding(
                get: { EventKind.allCases.firstIndex(of: viewModel.kind) ?? 0 },
                set: { viewModel.kind = EventKind.allCases[$0] }
            )
        )

        FormLabel("Name").padding(.top, Tokens.Spacing.loose)
        TextField(viewModel.isRace ? "Norwich Autumn Head" : "Club dinner", text: $viewModel.name)
            .textStyle(Typography.bodyV3)
            .padding(.horizontal, Tokens.Spacing.card)
            .formFieldBox()

        HStack(alignment: .top, spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 0) {
                FormLabel("First day")
                DatePicker("First day", selection: $viewModel.firstDay, displayedComponents: .date)
                    .labelsHidden()
                    .formFieldBox()
            }
            VStack(alignment: .leading, spacing: 0) {
                FormLabel("Last day")
                if viewModel.isOneDay {
                    Button("Same day") { viewModel.lastDay = viewModel.firstDay; viewModel.isOneDay = false }
                        .textStyle(Typography.bodyV3)
                        .foregroundStyle(Tokens.Ink.primary)
                        .formFieldBox()
                        .accessibilityHint("Choose a later last day")
                } else {
                    DatePicker("Last day", selection: $viewModel.lastDay, in: viewModel.firstDay..., displayedComponents: .date)
                        .labelsHidden()
                        .formFieldBox()
                    Button("Same day") { viewModel.isOneDay = true }
                        .buttonStyle(.rpText)
                }
            }
        }
        .padding(.top, Tokens.Spacing.loose)

        FormLabel("Place").padding(.top, Tokens.Spacing.loose)
        TextField("River Wensum, Norwich", text: $viewModel.place)
            .textStyle(Typography.bodyV3)
            .padding(.horizontal, Tokens.Spacing.card)
            .formFieldBox()

        FormSectionTitle("Squads")
        WrapLayout(spacing: Tokens.Spacing.tight) {
            Button("Whole club") { viewModel.squadIds = [] }
                .buttonStyle(.rpPill(isOn: viewModel.squadIds.isEmpty))
            ForEach(viewModel.squads) { squad in
                Button(squad.name) { viewModel.toggle(squad) }
                    .buttonStyle(.rpPill(isOn: viewModel.squadIds.contains(squad.id)))
            }
        }

        FormLabel("Note").padding(.top, Tokens.Spacing.loose)
        TextField("Entries close Mon 26 Oct. Boats leave at 07:30.", text: $viewModel.note, axis: .vertical)
            .textStyle(Typography.bodyV3)
            .lineLimit(2...5)
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .formFieldBox()

        ToggleCard(title: viewModel.isRace ? "Ask who can race" : "Ask who can come",
                   detail: "Rowers answer in their Calendar. You see the answers on the \(viewModel.isRace ? "race" : "event").",
                   isOn: $viewModel.asksAvailability)
            .padding(.top, Tokens.Spacing.group)

        if let problem = viewModel.problem, !viewModel.name.isEmpty {
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
                Text(viewModel.isNew ? "Add to calendar" : "Save changes")
            }
        }
        .buttonStyle(.rpPrimary)
        .disabled(viewModel.isSaving || viewModel.problem != nil)
        .padding(.top, Tokens.Spacing.group)

        if viewModel.isNew {
            FormFootnote("\(viewModel.audienceCount) rower\(viewModel.audienceCount == 1 ? "" : "s") \(viewModel.squadIds.isEmpty ? "in the club" : "in these squads") \(viewModel.audienceCount == 1 ? "is" : "are") told.")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        } else {
            Button(viewModel.isRace ? "Delete race" : "Delete event") { isConfirmingDelete = true }
                .buttonStyle(.rpDestructive)
                .disabled(viewModel.isSaving)
                .padding(.top, Tokens.Spacing.tight)
        }
    }
}
