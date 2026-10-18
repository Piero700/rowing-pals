//
//  RowerPracticeView.swift
//  Rowing Pals
//

import SwiftUI

/// One practice, for the rower it's set for (RowerPractice; decisions 39, 68): when and where,
/// Available · Can't with a reason only coaches see, Check in on the day, and the coach's mark,
/// which always counts.
struct RowerPracticeView: View {
    @State private var viewModel: RowerPracticeViewModel
    @Environment(\.dismiss) private var dismiss

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let field = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)

    init(practiceId: UUID) {
        _viewModel = State(initialValue: RowerPracticeViewModel(practiceId: practiceId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let practice = viewModel.practice {
                    summary(practice)
                    if practice.cancelled {
                        Text("Your coach cancelled this practice.")
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.System.error)
                            .padding(.horizontal, 4)
                            .padding(.top, Tokens.Spacing.loose)
                    } else {
                        answerSection
                        checkInSection(practice)
                    }
                    markSection
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
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Practice") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
    }

    private func summary(_ practice: Practice) -> some View {
        let calendar = viewModel.calendar
        return VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            HStack(spacing: Tokens.Spacing.loose) {
                DateBlock(date: practice.startsAt, calendar: calendar)
                VStack(alignment: .leading, spacing: 2) {
                    Text(practice.displayTitle)
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(CalendarRules.repeatCaption(practice, calendar: calendar).map { "Weekly · \($0)" } ?? "One-off")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            detail(.clock, "\(CalendarRules.time(practice.startsAt, calendar: calendar))–\(CalendarRules.time(practice.endsAt, calendar: calendar))")
            if let place = practice.place { detail(.pin, place) }
            if let setBy = viewModel.setByName { detail(.people, "Set by \(setBy)") }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .padding(.top, Tokens.Spacing.tight)
    }

    private func detail(_ symbol: RPIcon, _ text: String) -> some View {
        HStack(spacing: Tokens.Spacing.gap) {
            RPIconView(icon: symbol, size: Tokens.Icon.detail)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(text)
                .textStyle(Typography.bodySecondary)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        SectionTitle("Your answer")
            .padding(.top, Tokens.Spacing.group)
            .padding(.bottom, Tokens.Spacing.tight)
        AnswerControl(answer: viewModel.answer, isEnabled: viewModel.canAnswer && !viewModel.isSaving, isWide: true) { answer in
            Task { await viewModel.setAnswer(answer) }
        }
        if viewModel.answer == .cant {
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
            .overlay { Self.field.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
            .padding(.top, Tokens.Spacing.loose)
            Text("Only your club’s coaches see your reason.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.tight)
        }
        if !viewModel.canAnswer {
            Text("This practice has started, so your answer can’t change now.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.tight)
        }
    }

    @ViewBuilder
    private func checkInSection(_ practice: Practice) -> some View {
        SectionTitle("On the day")
            .padding(.top, Tokens.Spacing.group)
            .padding(.bottom, Tokens.Spacing.tight)
        if let checkedIn = viewModel.checkedInAt {
            Label("Checked in at \(CalendarRules.time(checkedIn, calendar: viewModel.calendar))", icon: .checkCircle)
                .textStyle(Typography.rowTitle)
                .tabularNumerals()
                .foregroundStyle(Tokens.Accent.success)
                .padding(.horizontal, 4)
        } else {
            Button {
                Task { await viewModel.checkIn() }
            } label: {
                Label("Check in", icon: .check, size: Tokens.Icon.small)
            }
            .buttonStyle(.rpPrimary)
            .disabled(!viewModel.canCheckIn || viewModel.isSaving)
            Text("Check-in opens 30 minutes before the start.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.tight)
        }
    }

    @ViewBuilder
    private var markSection: some View {
        SectionTitle("Coach’s mark")
            .padding(.top, Tokens.Spacing.group)
            .padding(.bottom, Tokens.Spacing.tight)
        if let mark = viewModel.mark {
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mark.mark.label)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(markedLine(mark))
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if mark.mark.counted {
                    Text(mark.mark.attended ? "Counts" : "Missed")
                        .textStyle(Typography.chip)
                        .foregroundStyle(mark.mark.attended ? Tokens.Accent.success : Tokens.Ink.secondary)
                }
            }
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        } else {
            Text("No mark yet.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
        }
        Text(viewModel.markIsFromLastPractice
             ? "Your coach’s mark always counts over your own answer. This shows the last practice."
             : "Your coach’s mark always counts over your own answer.")
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.tight)
    }

    private func markedLine(_ mark: AttendanceMark) -> String {
        let when = "\(CalendarRules.dayLabel(mark.setAt, calendar: viewModel.calendar)), \(CalendarRules.time(mark.setAt, calendar: viewModel.calendar))"
        return viewModel.markedByName.map { "Marked by \($0) · \(when)" } ?? "Marked \(when)"
    }
}
