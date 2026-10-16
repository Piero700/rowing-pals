//
//  CoachRowersView.swift
//  Rowing Pals
//

import SwiftUI

/// The coach version's **Rowers** tab (CoachRowers; decisions 39, 43, 62, 67): every rowing member
/// with this week against their target, their 2k and prediction, attendance and flags — filtered by
/// squad and sorted from one button. Squads and the coach's own Profile sit top right.
struct CoachRowersView: View {
    /// Taps on the tab while it's showing: scroll to the top and refresh (decision 27).
    var reselects = 0
    /// Bumped by the coach app when a screen it opened closes, so a change made there shows here.
    var refreshes = 0

    @State private var viewModel = CoachingViewModel()
    @State private var isShowingFilters = false
    @Environment(\.navigate) private var navigate

    private static let statShape = RoundedRectangle(cornerRadius: Tokens.Coaching.statRadius, style: .continuous)

    var body: some View {
        // The scroll view stays the tab's root view so the floating bar can track it.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let roster = viewModel.roster {
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
                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) { ViewerContext.shared.invalidate(); await viewModel.load() }
        .safeAreaInset(edge: .top, spacing: 0) {
            CoachTabHeader(title: "Rowers") {
                GlassIconButton(systemImage: "person.3", accessibilityLabel: "Squads") { navigate(.squads) }
            }
        }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.load() }
        .onChange(of: refreshes) { Task { await viewModel.load() } }
        .refreshable {
            ViewerContext.shared.invalidate()
            await viewModel.load()
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
