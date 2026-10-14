//
//  CoachingView.swift
//  Rowing Pals
//

import SwiftUI

/// Coaching (CoachRowers, CoachWorkouts; decisions 34, 39, 43): a full-screen area for a club's
/// coaches, opened from Your crew or Profile → Club. **Rowers** — every rowing member with this
/// week against their target, their 2k and prediction, and flags — filtered by squad and
/// sorted; **Workouts** — the workouts the club's coaches have set, and New workout. Squads sits
/// top right. The Practices tab and attendance arrive with Phase 3.
struct CoachingView: View {
    @State private var viewModel = CoachingViewModel()
    @State private var workouts = WorkoutsViewModel()
    @State private var tab: Tab = .rowers

    private enum Tab: Int, CaseIterable {
        case rowers, workouts
        var label: String { self == .rowers ? "Rowers" : "Workouts" }
    }
    @State private var isShowingFilters = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let statShape = RoundedRectangle(cornerRadius: Tokens.Coaching.statRadius, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PillSegmentedControl(
                    options: Tab.allCases.map(\.label),
                    selection: Binding(get: { tab.rawValue }, set: { tab = Tab(rawValue: $0) ?? .rowers })
                )
                .padding(.bottom, Tokens.Spacing.loose)

                if tab == .workouts {
                    workoutsContent
                } else if let roster = viewModel.roster {
                    content(roster)
                } else if viewModel.isLoading {
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
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        // Also on coming back from Squads, so a changed squad shows at once.
        .onAppear {
            Task { await viewModel.load() }
            Task { await workouts.load() }
        }
        .refreshable {
            ViewerContext.shared.invalidate()
            if tab == .workouts { await workouts.load() } else { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.load() }
        }
        .sheet(isPresented: $isShowingFilters) {
            RosterFiltersSheet(
                squads: viewModel.roster?.squads ?? [],
                rowerCount: viewModel.roster?.rowers.count ?? 0,
                squad: viewModel.squad,
                sort: viewModel.sort
            ) { squad, sort in
                viewModel.squad = squad
                viewModel.sort = sort
            }
        }
    }

    /// Close · Coaching · Squads.
    private var header: some View {
        ZStack {
            HStack(spacing: 0) {
                GlassIconButton(systemImage: "xmark", accessibilityLabel: "Close") { dismiss() }
                Spacer(minLength: 0)
                GlassIconButton(systemImage: "person.3", accessibilityLabel: "Squads") { navigate(.squads) }
            }
            Text("Coaching")
                .textStyle(Typography.navTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, Tokens.Spacing.tight)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, Tokens.Spacing.loose)
        .frame(minHeight: Tokens.Size.navHeight)
        .background(Tokens.Base.ground)
    }

    @ViewBuilder
    private func content(_ roster: CoachingService.Roster) -> some View {
        // One button for squad and order: both open the same sheet (decision 62).
        HStack(spacing: Tokens.Spacing.tight) {
            Button { isShowingFilters = true } label: {
                Label("\(viewModel.squadName) · \(viewModel.sort.label)", systemImage: "line.3.horizontal.decrease")
                    .lineLimit(1)
            }
            .buttonStyle(.rpPill(isOn: false))
            .accessibilityHint("Choose a squad and how the rowers are ordered")
            Spacer(minLength: 0)
        }

        HStack(spacing: Tokens.Spacing.tight) {
            stat("\(viewModel.behindCount)", "behind target")
            stat("\(viewModel.flaggedCount)", "flagged")
            if let attendance = viewModel.attendanceText {
                stat(attendance, "attendance")
            }
        }
        .padding(.top, Tokens.Spacing.loose)

        let rowers = viewModel.rowers
        Text("This week · \(rowers.count) rower\(rowers.count == 1 ? "" : "s")")
            .textStyle(Typography.sectionTitle)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.sectionTop)
            .padding(.bottom, Tokens.Spacing.tight)
            .accessibilityAddTraits(.isHeader)

        if rowers.isEmpty {
            Text(viewModel.squad == nil ? "Nobody who rows is in \(roster.clubName) yet." : "Nobody is in this squad yet.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
        } else {
            LazyVStack(spacing: Tokens.Spacing.tight) {
                ForEach(rowers) { rower in
                    RowerCard(rower: rower, attendance: viewModel.attendance[rower.id])
                        .asButton { navigate(.coachRower(rower.id)) }
                }
            }
        }

        Text("Predictions and flags come from the Pace Engine.")
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, Tokens.Spacing.loose)
    }

    // MARK: - Workouts

    @ViewBuilder
    private var workoutsContent: some View {
        Button {
            navigate(.newWorkout)
        } label: {
            Label("New workout", systemImage: "plus")
        }
        .buttonStyle(.rpPrimary)

        if let error = workouts.errorMessage {
            Text(error)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.loose)
        }
        if workouts.hasLoaded && workouts.today.isEmpty && workouts.upcoming.isEmpty && workouts.past.isEmpty {
            Text("No workouts yet. Set one and the rowers it's for are told, and see it on the day.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.group)
        }
        workoutSection("Today", workouts.today, isToday: true)
        workoutSection("Upcoming", workouts.upcoming, isToday: false)
        workoutSection("Past", workouts.past, isToday: false)
    }

    @ViewBuilder
    private func workoutSection(_ title: String, _ items: [WorkoutsViewModel.Item], isToday: Bool) -> some View {
        if !items.isEmpty {
            Text(title)
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.group)
                .padding(.bottom, Tokens.Spacing.tight)
                .accessibilityAddTraits(.isHeader)
            LazyVStack(spacing: Tokens.Spacing.tight) {
                ForEach(items) { item in
                    WorkoutCard(item: item, isToday: isToday)
                        .asButton { navigate(.workoutResults(item.workout.id)) }
                        // As well as Delete workout on its page (decision 60).
                        .swipeToDelete { await workouts.delete(item.workout.id) }
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .textStyle(Typography.coachStat)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
            Text(label)
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.loose)
        .background(Self.statShape.fill(Tokens.Surface.card))
        .overlay { Self.statShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}
