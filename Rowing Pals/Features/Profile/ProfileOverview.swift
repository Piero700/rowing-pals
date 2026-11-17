//
//  ProfileOverview.swift
//  Rowing Pals
//

import SwiftUI

/// Profile's Overview tab: the top two PBs, the 2k and 5k prediction cards (your own profile), the
/// weekly volume chart, the consistency grid, the most recent workout, then Season Wrapped and the
/// club entry (your own profile).
struct ProfileOverview: View {
    let viewModel: ProfileViewModel
    let onOpenTest: (StandardTest) -> Void
    let onShowAllPBs: () -> Void
    let onExplain: (ProfileView.PredictedDistance) -> Void
    @Environment(\.navigate) private var navigate

    private static let pbKeys = ["2k", "5k"]
    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileSectionHeader(text: "Top personal bests") {
                Button("View all ›", action: onShowAllPBs)
                    .buttonStyle(.rpText)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight), count: 2),
                      spacing: Tokens.Spacing.tight) {
                ForEach(viewModel.pbTiles.filter { Self.pbKeys.contains($0.test.key) }) { tile in
                    PBTileView(tile: tile) { onOpenTest(tile.test) }
                }
            }

            if viewModel.isOwnProfile {
                VStack(spacing: Tokens.Spacing.gap) {
                    ForEach(ProfileView.predictedDistances, id: \.metres) { target in
                        PredictionCard(
                            title: target.title,
                            prediction: viewModel.predictions[target.metres],
                            isLoading: viewModel.isLoadingPredictions,
                            didFail: viewModel.predictionsFailed,
                            onRetry: { Task { await viewModel.loadPredictions() } }
                        ) { onExplain(target) }
                    }
                }
                .padding(.top, Tokens.Spacing.loose)
            }

            ProfileSectionHeader(text: "Weekly volume") { ProfileChip(text: "12 weeks") }
                .padding(.top, 4)
            WeeklyVolumeChart(weeks: viewModel.weeklyVolumes)
                .padding(.vertical, 16)
                .padding(.horizontal, Tokens.Spacing.card)
                .background(Self.shape.fill(Tokens.Surface.card))
                .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }

            ProfileSectionHeader(text: "Consistency") { ProfileChip(text: "\(viewModel.activeDaysInGrid) active days") }
            ConsistencyCalendarView(days: viewModel.consistencyDays, footnote: streakFootnote)
                .padding(.vertical, 16)
                .padding(.horizontal, Tokens.Spacing.card)
                .background(Self.shape.fill(Tokens.Surface.card))
                .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }

            if let latest = viewModel.latestSession {
                ProfileSectionTitle(text: "Recent activity")
                ProfileRecentActivity(session: latest)
            }

            if viewModel.isOwnProfile {
                // Season Wrapped (decision 92): any time, for this term so far or any before.
                Button {
                    navigate(.seasonWrapped(nil))
                } label: {
                    Label("Season Wrapped", icon: .star)
                }
                .buttonStyle(.rpGlass)
                .padding(.top, Tokens.Spacing.group)
                ProfileClubEntry(viewModel: viewModel)
            }
        }
    }

    /// v3 streak footnote, carrying the rest-day allowance the old streak block showed.
    private var streakFootnote: String {
        let remaining = max(0, viewModel.restDaysAllowedPerWeek - viewModel.restDaysUsedThisWeek)
        let rest = "\(remaining) rest day\(remaining == 1 ? "" : "s") left this week"
        if viewModel.streakDays > 0 {
            return "\(viewModel.streakDays)-day current streak · \(rest)"
        }
        return "Post a workout to start a streak · \(rest)"
    }
}
