//
//  RowerCalendarView.swift
//  Rowing Pals
//

import SwiftUI

/// The rower's **Calendar** tab (RowerCalendar; decision 68): this week or next, a week ahead by
/// default. Each day lists its sessions with Available · Can't — morning and evening answered
/// separately, or the whole day at once — and the workouts set for it; then the races coming up
/// with "Can you race?". Tapping a session opens it (a reason for Can't, check-in, the coach's mark).
struct RowerCalendarView: View {
    /// Taps on the tab while it's showing: scroll to the top and refresh (decision 27).
    var reselects = 0

    @State private var viewModel = RowerCalendarViewModel()
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PillSegmentedControl(options: ["This week", "Next week"], selection: Binding(
                    get: { viewModel.week.rawValue },
                    set: { viewModel.week = RowerCalendarViewModel.Week(rawValue: $0) ?? .next }
                ))
                Text(weekCaption)
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, Tokens.Spacing.tight)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }

                if !viewModel.hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    if !viewModel.openPractices.isEmpty {
                        answerBanner
                    } else if viewModel.practices.isEmpty {
                        Text("No sessions set for you this week yet. When your coaches add practices, they show here.")
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.horizontal, 4)
                            .padding(.top, Tokens.Spacing.loose)
                    }
                    VStack(spacing: Tokens.Spacing.tight) {
                        ForEach(viewModel.days, id: \.self) { day in
                            dayCard(day)
                        }
                    }
                    .padding(.top, Tokens.Spacing.loose)
                    racesSection
                    Text("You can change an answer until the session starts. Your coaches see it straight away.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }
                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) { await viewModel.load() }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .practiceAnswered)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .calendarChanged)) { _ in
            Task { await viewModel.load() }
        }
    }

    private var header: some View {
        HStack(spacing: Tokens.Spacing.gap) {
            Text("Calendar")
                .textStyle(Typography.largeTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, 14)
        .frame(minHeight: Tokens.Size.headerMinHeight)
        .background(Tokens.Base.ground)
    }

    private var weekCaption: String {
        let club = viewModel.clubName.map { " · \($0)’s weeks start on \(viewModel.weekStart.label)" } ?? ""
        return viewModel.rangeText + club
    }

    // MARK: - Say which sessions you can make

    private var answerBanner: some View {
        let total = viewModel.openPractices.count
        let answered = viewModel.answeredCount
        let rest = viewModel.restToAnswer.count
        return VStack(alignment: .leading, spacing: 2) {
            Text("Say which sessions you can make")
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Tokens.Ink.primary)
            Text("\(answered) of \(total) answered. Your coaches plan the week from your answers, so a week’s notice helps.")
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
            ProgressView(value: Double(answered), total: Double(max(total, 1)))
                .tint(Tokens.Accent.brand)
                .padding(.vertical, Tokens.Spacing.loose)
            if rest > 0 {
                Button {
                    Task { await viewModel.answerRestAvailable() }
                } label: {
                    Label("Available for the other \(rest)", systemImage: "checkmark")
                }
                .buttonStyle(.rpGlass)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(LinearGradient(colors: [Tokens.Accent.brandSoft, Tokens.Surface.card],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .padding(.top, Tokens.Spacing.loose)
    }

    // MARK: - A day

    @ViewBuilder
    private func dayCard(_ day: Date) -> some View {
        let sessions = viewModel.practices(on: day)
        let others = viewModel.otherWorkouts(on: day)
        let calendar = viewModel.calendar
        if sessions.isEmpty && others.isEmpty {
            HStack(spacing: Tokens.Spacing.loose) {
                DateBlock(date: day, calendar: calendar, isQuiet: true)
                Text("Nothing on")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Tokens.Spacing.gap) {
                    DateBlock(date: day, calendar: calendar)
                    if !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Whole day")
                                .textStyle(Typography.pill)
                                .foregroundStyle(Tokens.Ink.primary)
                            Text(CalendarRules.daySummary(sessions.map { ($0, viewModel.answers[$0.id]) }, calendar: calendar))
                                .textStyle(Typography.statLabel)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        AnswerControl(
                            answer: CalendarRules.wholeDay(sessions.map { viewModel.answers[$0.id] }),
                            isEnabled: sessions.contains { CalendarRules.canAnswer($0, now: Date()) }
                        ) { answer in
                            Task { await viewModel.answerDay(day, answer) }
                        }
                    } else {
                        Spacer(minLength: 0)
                    }
                }
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, practice in
                    sessionRow(practice, isFirst: index == 0)
                }
                ForEach(others) { workout in
                    workoutRow(workout, isFirst: sessions.isEmpty)
                }
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        }
    }

    private func sessionRow(_ practice: Practice, isFirst: Bool) -> some View {
        let calendar = viewModel.calendar
        let workouts = viewModel.workouts(during: practice)
        return VStack(alignment: .leading, spacing: 6) {
            if !isFirst { Rectangle().fill(Tokens.Surface.line).frame(height: 1) }
            HStack(spacing: Tokens.Spacing.gap) {
                Button {
                    navigate(.practice(practice.id))
                } label: {
                    HStack(spacing: Tokens.Spacing.gap) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(CalendarRules.time(practice.startsAt, calendar: calendar))
                                .textStyle(Typography.rowTitle)
                            Text(CalendarRules.time(practice.endsAt, calendar: calendar))
                                .textStyle(Typography.statLabel)
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                        .tabularNumerals()
                        .frame(width: Tokens.Schedule.timeColumn, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(practice.displayTitle)
                                .textStyle(Typography.rowTitle)
                            if let place = practice.place {
                                Text(place)
                                    .textStyle(Typography.statLabel)
                                    .foregroundStyle(Tokens.Ink.secondary)
                            }
                            ForEach(workouts) { workout in
                                Text("Workout: \(workout.title)")
                                    .textStyle(Typography.statLabel)
                                    .foregroundStyle(Tokens.Accent.brand)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(Tokens.Ink.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
                AnswerControl(
                    answer: viewModel.answers[practice.id],
                    isEnabled: CalendarRules.canAnswer(practice, now: Date())
                ) { answer in
                    Task { await viewModel.answer(practice, answer) }
                }
            }
            if viewModel.answers[practice.id] == .cant, let reason = viewModel.reasons[practice.id] {
                Text("“\(reason)” · only your coaches see this")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.leading, Tokens.Schedule.timeColumn + Tokens.Spacing.gap)
            }
        }
        .padding(.top, Tokens.Spacing.loose)
    }

    private func workoutRow(_ workout: CoachWorkout, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !isFirst { Rectangle().fill(Tokens.Surface.line).frame(height: 1) }
            HStack(spacing: Tokens.Spacing.gap) {
                Text(WorkoutRules.startDate(workout, calendar: viewModel.calendar).map { CalendarRules.time($0, calendar: viewModel.calendar) } ?? "")
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .frame(width: Tokens.Schedule.timeColumn, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Workout: \(workout.title)")
                        .textStyle(Typography.rowTitle)
                    Text("From your coach")
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(.top, Tokens.Spacing.loose)
    }

    // MARK: - Races and regattas

    @ViewBuilder
    private var racesSection: some View {
        let events = viewModel.events
        if !events.isEmpty {
            SectionTitle("Races and events")
                .padding(.top, Tokens.Spacing.group)
            VStack(spacing: Tokens.Spacing.tight) {
                ForEach(events) { event in
                    eventCard(event)
                }
            }
        }
    }

    private func eventCard(_ event: ClubEvent) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.gap) {
            // The race's page takes a reason with Can't (only coaches see it).
            Button { navigate(.event(event.id)) } label: { HStack(spacing: Tokens.Spacing.loose) {
                Image(systemName: event.kind == .race ? "flag" : "calendar")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(width: Tokens.Schedule.iconTile, height: Tokens.Schedule.iconTile)
                    .background(RoundedRectangle(cornerRadius: Tokens.Schedule.iconTileRadius, style: .continuous).fill(Tokens.Surface.raised))
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.name)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text([CalendarRules.eventDays(event, calendar: viewModel.calendar), event.place].compactMap { $0 }.joined(separator: " · "))
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                    if let note = event.note {
                        Text(note)
                            .textStyle(Typography.statLabel)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .foregroundStyle(Tokens.Ink.primary)
            .contentShape(Rectangle()) }
            .buttonStyle(IconPressStyle())
            if event.asksAvailability {
                HStack {
                    Text(event.kind == .race ? "Can you race?" : "Can you come?")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                    Spacer(minLength: 0)
                    AnswerControl(answer: viewModel.eventAnswers[event.id].map { $0 ? .going : .cant }) { answer in
                        Task { await viewModel.answer(event, canCome: answer == .going) }
                    }
                }
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }
}
