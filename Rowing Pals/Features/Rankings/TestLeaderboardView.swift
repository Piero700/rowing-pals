//
//  TestLeaderboardView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 6B — one standard distance's leaderboard. Male/Female on top,
/// All/Novice/Senior beneath, filtering on the snapshot columns baked into
/// each `test_results` row — never the rower's live profile (task 11's
/// whole point). Works for any of the nine standard tests, not just 2k.
struct TestLeaderboardView: View {
    @State private var viewModel: TestLeaderboardViewModel
    @Environment(\.dismiss) private var dismiss
    /// Redesign phase B — per-device display preference, not synced to
    /// the profile. `row.splitValue` itself is already formatted by the
    /// view model per this same preference (read fresh from UserDefaults
    /// there); this view only needs it to decide whether the hand-appended
    /// "/500m" suffix still applies (never shown for watts).
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split
    /// Redesign phase D — single Filters sheet replacing the two stacked
    /// inline segmented controls, see RankingsFilters.swift.
    @State private var isShowingFilters = false
    /// Deletes this club test (decision 28); nil for a standard test, or a rower who can't.
    private let onDelete: (() async throws -> Void)?
    @State private var isConfirmingDelete = false
    @State private var deleteError: String?

    init(test: StandardTest, onDelete: (() async throws -> Void)? = nil) {
        _viewModel = State(initialValue: TestLeaderboardViewModel(test: test))
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    Text(viewModel.test.label)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                    if onDelete != nil {
                        Spacer(minLength: 0)
                        GlassIconButton(systemImage: "trash", accessibilityLabel: "Delete test", tint: Tokens.System.error) {
                            isConfirmingDelete = true
                        }
                    }
                }
                .padding(.top, 52)

                if let deleteError {
                    Text(deleteError)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                }

                HStack(spacing: 10) {
                    RankingsFiltersButton(filters: viewModel.filters) { isShowingFilters = true }
                }

                if viewModel.rows.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.rows) { row in
                            rowView(row)
                        }
                    }
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 14)
        }
        .background(Tokens.Base.ground)
        .edgeSwipeToDismiss()
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.reload() }
        // A club joined or left elsewhere changes who's on the My club board.
        .onReceive(NotificationCenter.default.publisher(for: .rowerClubChanged)) { _ in
            Task { await viewModel.reload() }
        }
        .sheet(isPresented: $isShowingFilters) {
            RankingsFiltersSheet(filters: $viewModel.filters)
        }
        .alert("Delete the \(viewModel.test.label) test?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its leaderboard and every result posted to it are deleted for the whole club. The sessions stay on the feed.")
        }
    }

    private func delete() async {
        guard let onDelete else { return }
        deleteError = nil
        do {
            try await onDelete()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                Text("Couldn't load this leaderboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text(errorMessage)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Nobody's set this test yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Post a \(viewModel.test.label) main piece to be the first.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    private func rowView(_ row: TestLeaderboardViewModel.Row) -> some View {
        let isPodium = row.rank <= 3
        return HStack(spacing: 11) {
            Text("\(row.rank)")
                .font(.system(size: 19, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(isPodium ? Tokens.Accent.records : Tokens.Ink.secondary)
                .frame(width: 24)
            AvatarPlaceholder(diameter: 40, streakDays: row.streakDays)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    if viewModel.filters.level == nil {
                        Text(row.category.rawValue.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Tokens.Ink.primary.opacity(0.1))
                            }
                    }
                    if row.isRecentPB {
                        Text("PB")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(Tokens.Base.dark)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Tokens.Accent.records)
                            }
                    }
                }
                Text("\(row.club ?? "No club") · \(row.dateLabel)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(row.primaryValue)
                    .font(.system(size: 18, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text(paceDisplay == .split ? "\(row.splitValue) /500m" : row.splitValue)
                    .font(.system(size: 12))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isPodium ? Tokens.Accent.records.opacity(0.07) : Tokens.Ink.primary.opacity(0.05))
        }
    }
}

#Preview {
    TestLeaderboardView(test: StandardTest.all[2])
}
