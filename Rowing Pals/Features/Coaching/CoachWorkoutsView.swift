//
//  CoachWorkoutsView.swift
//  Rowing Pals
//

import SwiftUI

/// The coach version's **Workouts** tab (CoachWorkouts; decisions 39, 52, 60, 67): the workouts the
/// club's coaches have set — Today, Upcoming, Past. A card opens its results; swiping it right to
/// left deletes it; today's have **Open notepad** under them (decision 96). New workout is the +
/// beside the tab bar.
struct CoachWorkoutsView: View {
    /// Taps on the tab while it's showing: scroll to the top and refresh (decision 27).
    var reselects = 0
    /// Bumped by the coach app when a screen it opened closes (a new or deleted workout).
    var refreshes = 0

    @State private var workouts = WorkoutsViewModel()
    @Environment(\.navigate) private var navigate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let error = workouts.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.bottom, Tokens.Spacing.loose)
                }
                if workouts.hasLoaded && workouts.today.isEmpty && workouts.upcoming.isEmpty && workouts.past.isEmpty {
                    Text("No workouts yet. Tap + to set one: the rowers it's for are told, and see it on the day.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                } else if !workouts.hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
                section("Today", workouts.today, isToday: true, isFirst: true)
                section("Upcoming", workouts.upcoming, isToday: false, isFirst: workouts.today.isEmpty)
                section("Past", workouts.past, isToday: false, isFirst: workouts.today.isEmpty && workouts.upcoming.isEmpty)
                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) { await workouts.load() }
        .safeAreaInset(edge: .top, spacing: 0) { CoachTabHeader(title: "Workouts") }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await workouts.load() }
        .onChange(of: refreshes) { Task { await workouts.load() } }
        .refreshable { await workouts.load() }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [WorkoutsViewModel.Item], isToday: Bool, isFirst: Bool) -> some View {
        if !items.isEmpty {
            HStack {
                Text(title)
                    .textStyle(Typography.sectionTitle)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Tokens.Spacing.tight)
                // Past → Notebook: a page per past workout's notepad (CoachNotepadWorkouts, NP4).
                if title == "Past" {
                    Button {
                        navigate(.notebook)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Notebook")
                            RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                        }
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Accent.brand)
                        .frame(minHeight: Tokens.Size.minTap)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, isFirst ? 0 : Tokens.Spacing.group)
            .padding(.bottom, title == "Past" ? 0 : Tokens.Spacing.tight)
            LazyVStack(spacing: Tokens.Spacing.tight) {
                ForEach(items) { item in
                    if isToday {
                        // Today's card has Open notepad inside it, under the bar (CoachNotepadWorkouts).
                        // The card is drawn around both, so the two stay separate buttons.
                        VStack(spacing: 0) {
                            WorkoutCard(item: item, isToday: true, drawsCard: false)
                                .asButton { navigate(.workoutResults(item.workout.id)) }
                            // A thin row under the bar, in the grouped style (decision 97, app-wide).
                            GroupedDivider()
                            Button {
                                navigate(.notepad(item.workout.id))
                            } label: {
                                HStack(spacing: Tokens.Spacing.tight) {
                                    RPIconView(icon: .pencil, size: Tokens.Icon.small)
                                    Text("Open notepad")
                                    Spacer(minLength: 0)
                                    RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                                        .foregroundStyle(Tokens.Ink.faint)
                                }
                                .textStyle(Typography.detail)
                                .foregroundStyle(Tokens.Accent.brand)
                                .padding(.horizontal, Tokens.Grouped.rowPadding)
                                .frame(minHeight: Tokens.Grouped.rowHeight)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(IconPressStyle())
                        }
                        .background { WorkoutCard.card }
                        // As well as Delete workout on its page (decision 60).
                        .swipeToDelete { await workouts.delete(item.workout.id) }
                    } else {
                        WorkoutCard(item: item, isToday: false)
                            .asButton { navigate(.workoutResults(item.workout.id)) }
                            .swipeToDelete { await workouts.delete(item.workout.id) }
                    }
                }
            }
        }
    }
}
