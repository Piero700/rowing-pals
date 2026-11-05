//
//  AnnouncementEditorView.swift
//  Rowing Pals
//

import SwiftUI

/// New announcement or edit one (CoachAnnouncementNew, CoachAnnouncementEdit; decision 75): Heading
/// (all rowers see until they tap it), Message, On the Feed for 24 hours · 3 days · 1 week · Until…,
/// Send an alert (new only), and Post announcement or Save changes; editing adds Delete.
struct AnnouncementEditorView: View {
    @State private var viewModel: AnnouncementEditorViewModel
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    init(announcementId: UUID?) {
        _viewModel = State(initialValue: AnnouncementEditorViewModel(announcementId: announcementId))
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
            ScreenHeader(title: viewModel.isNew ? "New announcement" : "Announcement", onBack: { dismiss() }) {
                HeaderSaveButton(title: viewModel.isNew ? "Post" : "Save", isSaving: viewModel.isSaving,
                                 isDisabled: !viewModel.hasLoaded || viewModel.problem != nil) {
                    Task { if await viewModel.save() { dismiss() } }
                }
            }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
        .alert("Delete this announcement?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It comes off every rower’s Feed straight away.")
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.Grouped.groupGap) {
            if let posted = viewModel.postedLine {
                Text(posted)
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, Tokens.Grouped.rowPadding)
            }

            GroupedSection(footer: "The heading is all rowers see on their Feed until they tap it.") {
                GroupedTextRow(label: "Heading", placeholder: "Kit order closes Friday", text: $viewModel.heading)
                GroupedDivider()
                GroupedNotesRow(placeholder: "The details", text: $viewModel.message, lines: 3...10)
            }

            GroupedSection(footer: "\(viewModel.expiryText) It stays in the Calendar.") {
                GroupedRow(label: "On the Feed for") {
                    Menu {
                        Picker("On the Feed for", selection: $viewModel.duration) {
                            ForEach(AnnouncementDuration.allCases, id: \.self) { duration in
                                Text(duration.label).tag(duration)
                            }
                        }
                    } label: {
                        GroupedValue(text: viewModel.duration.label)
                    }
                }
                if viewModel.duration == .custom {
                    GroupedDivider()
                    GroupedRow(label: "Until") {
                        DatePicker("Until", selection: $viewModel.until, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                }
            }

            if viewModel.isNew {
                GroupedSection(footer: "Every rower in your club sees it on their Feed.") {
                    GroupedToggleRow(label: "Send an alert",
                                     detail: "Rowers also get “New announcement: \(viewModel.heading.isEmpty ? "…" : viewModel.heading)”.",
                                     isOn: $viewModel.sendsAlert)
                }
            }

            if let problem = viewModel.problem, !viewModel.heading.isEmpty { GroupedError(text: problem) }
            if let error = viewModel.errorMessage { GroupedError(text: error) }

            if !viewModel.isNew {
                GroupedSection(footer: "Coaches, the owner and co-owners can edit or delete it.") {
                    GroupedButtonRow(title: "Delete announcement", isDestructive: true, isCentred: true) { isConfirmingDelete = true }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .padding(.top, Tokens.Spacing.tight)
    }
}
