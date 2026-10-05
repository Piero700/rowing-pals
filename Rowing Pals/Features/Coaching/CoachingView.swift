//
//  CoachingView.swift
//  Rowing Pals
//

import SwiftUI

/// Coaching (CoachRowers, decisions 34, 39, 43): a full-screen area for a club's coaches,
/// opened from Your crew or Profile → Club. Phase 1 is the **Rowers** list — every rowing member
/// with this week against their target, their 2k and prediction, and flags — filtered by squad
/// and sorted; Squads sits top right. The Workouts and Practices tabs, and attendance, arrive
/// with Phases 2 and 3.
struct CoachingView: View {
    @State private var viewModel = CoachingViewModel()
    @State private var isShowingFilters = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let statShape = RoundedRectangle(cornerRadius: Tokens.Coaching.statRadius, style: .continuous)

    var body: some View {
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
        .onAppear { Task { await viewModel.load() } }
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
        HStack(spacing: Tokens.Spacing.tight) {
            Button { isShowingFilters = true } label: {
                Label(viewModel.squadName, systemImage: "line.3.horizontal.decrease")
            }
            .buttonStyle(.rpPill(isOn: false))
            Button { isShowingFilters = true } label: {
                Label(viewModel.sort.label, systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.rpPill(isOn: false))
            Spacer(minLength: 0)
        }

        HStack(spacing: Tokens.Spacing.tight) {
            stat(viewModel.behindCount, "behind target")
            stat(viewModel.flaggedCount, "flagged")
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
                    RowerCard(rower: rower)
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

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
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
