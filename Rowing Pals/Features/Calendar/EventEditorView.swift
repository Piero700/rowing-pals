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
            ScreenHeader(title: viewModel.isNew ? "New race or event" : (viewModel.isRace ? "Edit race" : "Edit event"),
                         onBack: { dismiss() }) {
                HeaderSaveButton(title: viewModel.isNew ? "Add" : "Save", isSaving: viewModel.isSaving,
                                 isDisabled: !viewModel.hasLoaded || viewModel.problem != nil) {
                    Task { if await viewModel.save() { dismiss() } }
                }
            }
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

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.Grouped.groupGap) {
            PillSegmentedControl(
                options: EventKind.allCases.map(\.label),
                selection: Binding(
                    get: { EventKind.allCases.firstIndex(of: viewModel.kind) ?? 0 },
                    set: { viewModel.kind = EventKind.allCases[$0] }
                )
            )

            GroupedSection {
                GroupedTextRow(label: "Name", placeholder: viewModel.isRace ? "Norwich Autumn Head" : "Club dinner",
                               text: $viewModel.name)
                GroupedDivider()
                GroupedTextRow(label: "Place", placeholder: "River Wensum, Norwich", text: $viewModel.place)
            }

            GroupedSection {
                GroupedRow(label: "First day") {
                    DatePicker("First day", selection: $viewModel.firstDay, displayedComponents: .date)
                        .labelsHidden()
                }
                GroupedDivider()
                GroupedToggleRow(label: "More than one day", isOn: Binding(
                    get: { !viewModel.isOneDay },
                    set: { isLonger in
                        if isLonger { viewModel.lastDay = viewModel.firstDay }
                        viewModel.isOneDay = !isLonger
                    }
                ))
                if !viewModel.isOneDay {
                    GroupedDivider()
                    GroupedRow(label: "Last day") {
                        DatePicker("Last day", selection: $viewModel.lastDay, in: viewModel.firstDay..., displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }

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
                ? "\(viewModel.audienceCount) rower\(viewModel.audienceCount == 1 ? "" : "s") \(viewModel.squadIds.isEmpty ? "in the club" : "in these squads") \(viewModel.audienceCount == 1 ? "is" : "are") told."
                : nil) {
                GroupedToggleRow(label: viewModel.isRace ? "Ask who can race" : "Ask who can come",
                                 hint: "Rowers answer in their Calendar. You see the answers on the \(viewModel.isRace ? "race" : "event").",
                                 isOn: $viewModel.asksAvailability)
                GroupedDivider()
                GroupedNotesRow(placeholder: "Note: entries close Mon 26 Oct. Boats leave at 07:30.", text: $viewModel.note)
            }

            if let problem = viewModel.problem, !viewModel.name.isEmpty { GroupedError(text: problem) }
            if let error = viewModel.errorMessage { GroupedError(text: error) }

            if !viewModel.isNew {
                GroupedSection {
                    GroupedButtonRow(title: viewModel.isRace ? "Delete race" : "Delete event", isDestructive: true, isCentred: true) {
                        isConfirmingDelete = true
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
    }
}
