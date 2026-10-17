//
//  CoachCalendarView.swift
//  Rowing Pals
//

import SwiftUI

/// The coach version's **Calendar** tab (CoachCalendar; decisions 39, 68, 69), in place of the old
/// Practices list: the month, then the chosen day — its practices with who's available and Take
/// register, its land sessions and races — with Add for a practice, land session, race or event.
/// Then next week's availability and the races coming up. Who's available sits top right.
struct CoachCalendarView: View {
    var reselects = 0
    /// Bumped by the coach app when a screen it opened closes.
    var refreshes = 0

    @State private var viewModel = CoachCalendarViewModel()
    @State private var addingTo: AddTarget?
    @State private var chosenRoute: AppRoute?
    @Environment(\.navigate) private var navigate

    private struct AddTarget: Identifiable {
        let day: Date
        var id: Date { day }
    }

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MonthGridView(
                    month: viewModel.month,
                    grid: viewModel.grid,
                    selected: viewModel.selectedDay,
                    calendar: viewModel.calendar,
                    dots: { viewModel.dotCount(on: $0) },
                    hasEvent: { !viewModel.events(on: $0).isEmpty },
                    onSelect: { viewModel.selectedDay = $0 },
                    onMove: { viewModel.moveMonth(by: $0) }
                )

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }

                if !viewModel.announcements.isEmpty {
                    announcementsSection
                }

                ForEach(viewModel.shownDays, id: \.self) { day in
                    daySection(day)
                }

                if let summary = viewModel.nextWeekSummary {
                    availabilityCard(summary)
                }

                if !viewModel.upcomingEvents.isEmpty {
                    SectionTitle("Races and events coming up")
                        .padding(.top, Tokens.Spacing.group)
                        .padding(.bottom, Tokens.Spacing.tight)
                    VStack(spacing: Tokens.Spacing.tight) {
                        ForEach(viewModel.upcomingEvents) { event in
                            eventCard(event)
                        }
                    }
                }

                Text("Tap a day to see it. Weekly practices fill in by themselves until their end date. Weeks start on \(viewModel.weekStart.label): change it in Settings.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, Tokens.Spacing.loose)
                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) { await viewModel.load() }
        .safeAreaInset(edge: .top, spacing: 0) {
            CoachTabHeader(title: "Calendar") {
                GlassIconButton(systemImage: "person.crop.circle.badge.checkmark", accessibilityLabel: "Who’s available") {
                    navigate(.availability)
                }
            }
        }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.load() }
        .onChange(of: refreshes) { Task { await viewModel.load() } }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .calendarChanged)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .boatsChanged)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .announcementsChanged)) { _ in
            Task { await viewModel.load() }
        }
        .sheet(item: $addingTo, onDismiss: {
            if let route = chosenRoute {
                chosenRoute = nil
                navigate(route)
            }
        }) { target in
            CalendarAddSheet(day: target.day, calendar: viewModel.calendar) { route in
                chosenRoute = route
                addingTo = nil
            }
        }
    }

    // MARK: - A day

    @ViewBuilder
    private func daySection(_ day: Date) -> some View {
        HStack {
            SectionTitle(viewModel.heading(for: day))
            Spacer(minLength: 0)
            Button {
                addingTo = AddTarget(day: day)
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.rpPill(isOn: false))
        }
        .padding(.top, Tokens.Spacing.group)
        .padding(.bottom, Tokens.Spacing.tight)

        let practices = viewModel.practices(on: day)
        let workouts = viewModel.workouts(on: day)
        let events = viewModel.events(on: day)
        let water = viewModel.waterSessions(on: day)
        if practices.isEmpty && workouts.isEmpty && events.isEmpty && water.isEmpty {
            Text(viewModel.hasLoaded ? "Nothing on. Tap Add to set a practice, a land or water session, a race or an event." : "Loading…")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
        }
        VStack(spacing: Tokens.Spacing.tight) {
            ForEach(practices) { practice in
                practiceCard(practice, on: day)
            }
            ForEach(workouts) { workout in
                workoutCard(workout)
            }
            ForEach(water) { session in
                waterCard(session)
            }
            ForEach(events) { event in
                eventCard(event)
            }
        }
    }

    private func practiceCard(_ practice: Practice, on day: Date) -> some View {
        let calendar = viewModel.calendar
        let counts = viewModel.counts(for: practice)
        let canRegister = !practice.cancelled && calendar.startOfDay(for: practice.startsAt) <= viewModel.today
        return VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            Button {
                navigate(.editPractice(practice.id))
            } label: {
                HStack(spacing: Tokens.Spacing.gap) {
                    timeColumn(practice.startsAt, practice.endsAt)
                    VStack(alignment: .leading, spacing: 1) {
                        Text([practice.displayTitle, practice.place].compactMap { $0 }.joined(separator: " · "))
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(practice.cancelled ? Tokens.Ink.secondary : Tokens.Ink.primary)
                            .strikethrough(practice.cancelled)
                        Text([viewModel.squadText(for: practice), CalendarRules.repeatCaption(practice, calendar: calendar)].compactMap { $0 }.joined(separator: " · "))
                            .textStyle(Typography.statLabel)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .textStyle(Typography.pill)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())
            if practice.cancelled {
                chip("Cancelled")
            } else {
                HStack(spacing: 6) {
                    chip("\(counts.available) available")
                    chip("\(counts.cant) can’t")
                    chip("\(counts.noAnswer) no answer")
                }
            }
            if canRegister {
                Button {
                    navigate(.register(practice.id))
                } label: {
                    Label("Take register", systemImage: "checkmark")
                }
                .buttonStyle(.rpPrimary)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func workoutCard(_ workout: CoachWorkout) -> some View {
        Button {
            navigate(.workoutResults(workout.id))
        } label: {
            HStack(spacing: Tokens.Spacing.gap) {
                Text(WorkoutRules.startDate(workout, calendar: viewModel.calendar).map { CalendarRules.time($0, calendar: viewModel.calendar) } ?? "")
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(width: Tokens.Schedule.timeColumn, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Land session · \(workout.title)")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(workout.zone ?? "Erg workout")
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .contentShape(Self.cardShape)
        }
        .buttonStyle(IconPressStyle())
    }

    private func waterCard(_ session: WaterSession) -> some View {
        Button {
            navigate(.waterSession(session.id))
        } label: {
            HStack(spacing: Tokens.Spacing.gap) {
                Text(CalendarRules.time(session.startsAt, calendar: viewModel.calendar))
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(width: Tokens.Schedule.timeColumn, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Water · \(session.title)")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .multilineTextAlignment(.leading)
                    Text(viewModel.boatsLine(for: session))
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .contentShape(Self.cardShape)
        }
        .buttonStyle(IconPressStyle())
    }

    private func eventCard(_ event: ClubEvent) -> some View {
        let counts = viewModel.counts(for: event)
        return Button {
            navigate(.event(event.id))
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
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
                    if event.asksAvailability {
                        Text("\(counts.available) can \(event.kind == .race ? "race" : "come") · \(counts.cant) can’t · \(counts.noAnswer) no answer")
                            .textStyle(Typography.statLabel)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .contentShape(Self.cardShape)
        }
        .buttonStyle(IconPressStyle())
    }

    // MARK: - Announcements (decision 75)

    @ViewBuilder
    private var announcementsSection: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionTitle("Announcements")
            Spacer(minLength: 0)
            Text("\(viewModel.liveAnnouncementCount) on rowers’ Feeds")
                .textStyle(Typography.statLabel)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(.top, Tokens.Spacing.group)
        .padding(.bottom, Tokens.Spacing.tight)
        VStack(spacing: 0) {
            ForEach(Array(viewModel.announcements.enumerated()), id: \.element.id) { index, announcement in
                if index > 0 {
                    Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                }
                announcementRow(announcement)
            }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .clipShape(Self.cardShape)
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        Text("Tap one to change it or take it down. New ones come from +.")
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.tight)
    }

    private func announcementRow(_ announcement: Announcement) -> some View {
        let isLive = AnnouncementRules.isLive(announcement, now: Date())
        return Button {
            navigate(.editAnnouncement(announcement.id))
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                Image(systemName: "megaphone")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Tokens.Size.rowIcon, height: Tokens.Size.rowIcon)
                    .background(RoundedRectangle(cornerRadius: Tokens.Schedule.iconTileRadius, style: .continuous).fill(Tokens.Accent.brandSoft))
                VStack(alignment: .leading, spacing: 1) {
                    Text(announcement.heading)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    Text(viewModel.announcementLine(announcement))
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.gap)
            .frame(minHeight: Tokens.Size.row)
            .opacity(isLive ? 1 : 0.6)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
    }

    private func availabilityCard(_ summary: String) -> some View {
        Button {
            navigate(.availability)
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Tokens.Schedule.iconTile, height: Tokens.Schedule.iconTile)
                    .background(RoundedRectangle(cornerRadius: Tokens.Schedule.iconTileRadius, style: .continuous).fill(Tokens.Accent.brandSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next week’s availability")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(summary)
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(LinearGradient(colors: [Tokens.Accent.brandSoft, Tokens.Surface.card],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .contentShape(Self.cardShape)
        }
        .buttonStyle(IconPressStyle())
        .padding(.top, Tokens.Spacing.group)
    }

    private func timeColumn(_ start: Date, _ end: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(CalendarRules.time(start, calendar: viewModel.calendar))
                .textStyle(Typography.rowTitle)
                .foregroundStyle(Tokens.Ink.primary)
            Text(CalendarRules.time(end, calendar: viewModel.calendar))
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .tabularNumerals()
        .frame(width: Tokens.Schedule.timeColumn, alignment: .leading)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.chip)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.primary)
            .padding(.horizontal, Tokens.Spacing.tight)
            .padding(.vertical, 3)
            .background(Capsule().fill(Tokens.Surface.raised))
    }
}
