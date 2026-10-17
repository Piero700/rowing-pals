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
            ScreenHeader(title: viewModel.isNew ? "New announcement" : "Announcement") { dismiss() }
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

    @ViewBuilder
    private var form: some View {
        if let posted = viewModel.postedLine {
            Text(posted)
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.tight)
        }

        FormLabel("Heading").padding(.top, Tokens.Spacing.card)
        TextField("Kit order closes Friday", text: $viewModel.heading)
            .textStyle(Typography.bodyV3)
            .padding(.horizontal, Tokens.Spacing.card)
            .formFieldBox()
        FormFootnote("This is all rowers see on their Feed until they tap it.")

        FormLabel("Message").padding(.top, Tokens.Spacing.card)
        TextField("The details", text: $viewModel.message, axis: .vertical)
            .textStyle(Typography.bodyV3)
            .lineLimit(3...10)
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .formFieldBox()

        FormLabel("On the Feed for").padding(.top, Tokens.Spacing.card)
        PillSegmentedControl(options: AnnouncementDuration.allCases.map(\.label), selection: Binding(
            get: { viewModel.duration.rawValue },
            set: { viewModel.duration = AnnouncementDuration(rawValue: $0) ?? .day }
        ), compact: true)
        if viewModel.duration == .custom {
            DatePicker("Until", selection: $viewModel.until, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .formFieldBox()
                .padding(.top, Tokens.Spacing.tight)
        }
        FormFootnote("\(viewModel.expiryText) It stays in the Calendar.")

        if viewModel.isNew {
            ToggleCard(title: "Send an alert",
                       detail: "Rowers also get “New announcement: \(viewModel.heading.isEmpty ? "…" : viewModel.heading)”.",
                       isOn: $viewModel.sendsAlert)
                .padding(.top, Tokens.Spacing.group)
        }

        if let problem = viewModel.problem, !viewModel.heading.isEmpty {
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
                Text(viewModel.isNew ? "Post announcement" : "Save changes")
            }
        }
        .buttonStyle(.rpPrimary)
        .disabled(viewModel.isSaving || viewModel.problem != nil)
        .padding(.top, Tokens.Spacing.group)

        if viewModel.isNew {
            FormFootnote("Every rower in your club sees it on their Feed.")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        } else {
            Button("Delete announcement") { isConfirmingDelete = true }
                .buttonStyle(.rpDestructive)
                .disabled(viewModel.isSaving)
                .padding(.top, Tokens.Spacing.tight)
            FormFootnote("Coaches, the owner and co-owners can edit or delete it.")
        }
    }
}
