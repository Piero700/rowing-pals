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
            Text(title)
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, isFirst ? 0 : Tokens.Spacing.group)
                .padding(.bottom, Tokens.Spacing.tight)
                .accessibilityAddTraits(.isHeader)
            LazyVStack(spacing: Tokens.Spacing.tight) {
                ForEach(items) { item in
                    VStack(spacing: Tokens.Spacing.tight) {
                        WorkoutCard(item: item, isToday: isToday)
                            .asButton { navigate(.workoutResults(item.workout.id)) }
                            // As well as Delete workout on its page (decision 60).
                            .swipeToDelete { await workouts.delete(item.workout.id) }
                        if isToday {
                            Button {
                                navigate(.notepad(item.workout.id))
                            } label: {
                                Label("Open notepad", icon: .pencil, size: Tokens.Icon.small)
                            }
                            .buttonStyle(.rpPrimary)
                        }
                    }
                }
            }
        }
    }
}
