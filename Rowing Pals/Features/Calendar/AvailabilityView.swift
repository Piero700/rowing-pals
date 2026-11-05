//
//  AvailabilityView.swift
//  Rowing Pals
//

import SwiftUI

/// Who's available (CoachAvailability; decision 68), from the Calendar's header: This week · Next
/// week, every session at a glance (a bar of who can and can't), the chosen session's Available,
/// Can't make it and No answer yet, and the races coming up.
struct AvailabilityView: View {
    @State private var viewModel = AvailabilityViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let rowShape = RoundedRectangle(cornerRadius: Tokens.Schedule.iconTileRadius, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PillSegmentedControl(options: ["This week", "Next week"], selection: Binding(
                    get: { viewModel.week.rawValue },
                    set: { viewModel.week = AvailabilityViewModel.Week(rawValue: $0) ?? .next }
                ))
                Text(viewModel.caption)
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
                } else if viewModel.practices.isEmpty {
                    Text("No practices this week yet. Add them from the Calendar.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                } else {
                    glance
                    if let practice = viewModel.selected {
                        selectedSession(practice)
                    }
                }
                races
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Who’s available") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - At a glance

    private var glance: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("At a glance")
                    .textStyle(Typography.sectionTitle)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Text("of \(viewModel.everyone.count) rowers")
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.sectionTop)
            .padding(.bottom, Tokens.Spacing.tight)

            VStack(spacing: 0) {
                ForEach(viewModel.practices) { practice in
                    glanceRow(practice)
                }
            }
            .padding(.vertical, Tokens.Spacing.tight)
            .padding(.horizontal, 4)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        }
    }

    private func glanceRow(_ practice: Practice) -> some View {
        let counts = viewModel.counts(for: practice)
        let total = max(viewModel.audienceCount(for: practice), 1)
        let isSelected = viewModel.selected?.id == practice.id
        return Button {
            viewModel.selectedId = practice.id
        } label: {
            HStack(spacing: Tokens.Spacing.gap) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.glanceLabel(practice))
                        .textStyle(Typography.meta)
                        .fontWeight(.semibold)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(practice.displayTitle)
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
                .frame(width: Tokens.Schedule.glanceLabelWidth, alignment: .leading)
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        Rectangle().fill(Tokens.Accent.brand)
                            .frame(width: proxy.size.width * CGFloat(counts.available) / CGFloat(total))
                        Rectangle().fill(Tokens.Surface.line)
                            .frame(width: proxy.size.width * CGFloat(counts.cant) / CGFloat(total))
                        Spacer(minLength: 0)
                    }
                    .background(Tokens.Surface.raised)
                    .clipShape(Capsule())
                }
                .frame(height: Tokens.Schedule.barHeight)
                Text("**\(counts.available)** ✓ · \(counts.cant) ✗")
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(width: Tokens.Schedule.glanceCountWidth, alignment: .trailing)
            }
            .padding(.horizontal, Tokens.Spacing.loose)
            .padding(.vertical, 4)
            .frame(minHeight: Tokens.Size.control)
            .background(Self.rowShape.fill(isSelected ? Tokens.Accent.brandSoft : Color.clear))
            .contentShape(Self.rowShape)
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel("\(viewModel.glanceLabel(practice)), \(practice.displayTitle): \(counts.available) available, \(counts.cant) can’t")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - One session

    @ViewBuilder
    private func selectedSession(_ practice: Practice) -> some View {
        let lists = viewModel.lists(for: practice)
        let calendar = viewModel.calendar
        VStack(alignment: .leading, spacing: 2) {
            Text("\(CalendarRules.dayLabel(practice.startsAt, calendar: calendar)) · \(CalendarRules.time(practice.startsAt, calendar: calendar)) \(practice.displayTitle.lowercased())")
                .textStyle(Typography.cardTitle)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
            if let place = practice.place {
                Text(place)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, Tokens.Spacing.group)
        AnswerListCard(title: "Available", people: lists.available) { navigate(.coachRower($0)) }
        AnswerListCard(title: "Can’t make it", people: lists.cant) { navigate(.coachRower($0)) }
        AnswerListCard(title: "No answer yet", people: lists.none) { navigate(.coachRower($0)) }
        Button {
            Task { await planBoats(for: practice) }
        } label: {
            Label("Plan boats for this session", icon: .boat)
        }
        .buttonStyle(.rpGlass)
        .padding(.top, Tokens.Spacing.group)
        FormFootnote("Only available rowers are offered when you crew the boats.")
    }

    /// Opens the water session already planned for this practice, or a new one from it.
    private func planBoats(for practice: Practice) async {
        if let existing = try? await BoatService.session(forPractice: practice.id) {
            navigate(.waterSession(existing.id))
        } else {
            navigate(.newWaterSession(WaterSessionSeed(practiceId: practice.id)))
        }
    }

    // MARK: - Races

    @ViewBuilder
    private var races: some View {
        if !viewModel.events.isEmpty {
            FormSectionTitle("Races")
            VStack(spacing: Tokens.Spacing.tight) {
                ForEach(viewModel.events) { event in
                    raceRow(event)
                }
            }
        }
    }

    private func raceRow(_ event: ClubEvent) -> some View {
        let counts = viewModel.counts(for: event)
        return Button {
            navigate(.event(event.id))
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text([CalendarRules.eventDays(event, calendar: viewModel.calendar), event.place].compactMap { $0 }.joined(separator: " · "))
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                    Text("\(counts.available) can \(event.kind == .race ? "race" : "come") · \(counts.cant) can’t · \(counts.noAnswer) no answer")
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
            .contentShape(Self.cardShape)
        }
        .buttonStyle(IconPressStyle())
    }
}
