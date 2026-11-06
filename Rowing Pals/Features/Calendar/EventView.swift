//
//  EventView.swift
//  Rowing Pals
//

import SwiftUI

/// A race or event (CoachRace; decision 68). For a coach: the race with its counts, Can race (with
/// side), Can't race (with reasons), No answer yet, and Edit. For a rower it's for: the race and
/// Can you race? with a reason only coaches see.
struct EventView: View {
    @State private var viewModel: EventViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let field = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)

    init(eventId: UUID) {
        _viewModel = State(initialValue: EventViewModel(eventId: eventId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let event = viewModel.event {
                    summary(event)
                    if viewModel.isCoach {
                        coachLists(event)
                        if viewModel.isRace {
                            Button {
                                Task { await crewBoats(for: event) }
                            } label: {
                                Label("Crew boats for this race", icon: .boat)
                            }
                            .buttonStyle(.rpGlass)
                            .padding(.top, Tokens.Spacing.group)
                        }
                        Button(viewModel.isRace ? "Edit race" : "Edit event") { navigate(.editEvent(event.id)) }
                            .buttonStyle(.rpGlass)
                            .padding(.top, viewModel.isRace ? Tokens.Spacing.tight : Tokens.Spacing.group)
                    } else if event.asksAvailability {
                        rowerAnswer
                    }
                } else if viewModel.errorMessage == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: viewModel.event.map { $0.kind == .race ? "Race" : "Event" } ?? "") { dismiss() }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .calendarChanged)) { _ in
            Task { await viewModel.load() }
        }
    }

    private func summary(_ event: ClubEvent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BrandChip(text: event.kind == .race ? "Race" : "Event")
                Spacer(minLength: 0)
            }
            Text(event.name)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.top, 6)
            Text(viewModel.detailLine)
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
            if let note = event.note {
                Text(note)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.top, Tokens.Spacing.tight)
            }
            if viewModel.isCoach && event.asksAvailability {
                HStack(alignment: .top, spacing: 4) {
                    stat(viewModel.counts.available, viewModel.isRace ? "can race" : "can come")
                    stat(viewModel.counts.cant, "can’t")
                    stat(viewModel.counts.noAnswer, "no answer")
                }
                .padding(.top, Tokens.Spacing.loose)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    /// Opens the water session already planned for this race, or a new one from it: its boats
    /// are crewed from who said they can race.
    private func crewBoats(for event: ClubEvent) async {
        if let existing = try? await BoatService.session(event: event.id) {
            navigate(.waterSession(existing.id))
        } else {
            navigate(.newWaterSession(WaterSessionSeed(eventId: event.id)))
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .textStyle(Typography.coachStatSmall)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
            Text(label)
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func coachLists(_ event: ClubEvent) -> some View {
        if event.asksAvailability {
            AnswerListCard(title: viewModel.isRace ? "Can race" : "Can come", people: viewModel.canRace) { navigate(.coachRower($0)) }
            AnswerListCard(title: viewModel.isRace ? "Can’t race" : "Can’t come", people: viewModel.cantRace) { navigate(.coachRower($0)) }
            AnswerListCard(title: "No answer yet", people: viewModel.noAnswer) { navigate(.coachRower($0)) }
        } else {
            FormFootnote("Rowers aren’t asked who can come to this one. Turn on “Ask who can \(viewModel.isRace ? "race" : "come")” in Edit to ask them.")
                .padding(.top, Tokens.Spacing.loose)
        }
    }

    @ViewBuilder
    private var rowerAnswer: some View {
        SectionTitle(viewModel.isRace ? "Can you race?" : "Can you come?")
            .padding(.top, Tokens.Spacing.group)
            .padding(.bottom, Tokens.Spacing.tight)
        AnswerControl(answer: viewModel.myAnswer, isEnabled: viewModel.canAnswer && !viewModel.isSaving, isWide: true) { answer in
            Task { await viewModel.setAnswer(answer) }
        }
        if viewModel.myAnswer == .cant {
            HStack(spacing: Tokens.Spacing.tight) {
                TextField("Reason (optional)", text: $viewModel.reason)
                    .textStyle(Typography.body)
                    .foregroundStyle(Tokens.Ink.primary)
                    .submitLabel(.done)
                    .onSubmit { Task { await viewModel.saveReason() } }
                    .disabled(!viewModel.canAnswer)
                if viewModel.reasonChanged && viewModel.canAnswer {
                    Button("Save") { Task { await viewModel.saveReason() } }
                        .buttonStyle(.rpText)
                        .disabled(viewModel.isSaving)
                }
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .frame(minHeight: Tokens.Size.input)
            .background(Self.field.fill(Tokens.Surface.card))
            .overlay { Self.field.strokeBorder(Tokens.Surface.line, lineWidth: Tokens.Grouped.hairline) }
            .padding(.top, Tokens.Spacing.loose)
            FormFootnote("Only your club’s coaches see your reason.")
                .guidance()
        }
        if viewModel.canAnswer {
            FormFootnote("You can change your answer until the \(viewModel.isRace ? "race" : "event"). Your coaches see it straight away.")
                .guidance()
        } else {
            FormFootnote("This has finished, so your answer can’t change now.")
        }
    }
}
