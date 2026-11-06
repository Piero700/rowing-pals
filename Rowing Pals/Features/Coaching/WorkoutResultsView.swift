//
//  WorkoutResultsView.swift
//  Rowing Pals
//

import SwiftUI

/// One set workout's results, to the v4 CoachWorkoutResults artboard (decisions 49, 51): the
/// workout with how many have done it, partly or not yet; a filter; and each rower's reps
/// against their target split (− faster, + slower). Sessions count when a rower posts with
/// "Link this session" on. Edit (user, 2026-11-05) and the notepad (decision 96) are top right; Delete
/// workout sits at the bottom.
struct WorkoutResultsView: View {
    @State private var viewModel: WorkoutResultsViewModel
    @State private var isConfirmingDelete = false
    @State private var hasAppeared = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(workoutId: UUID) {
        _viewModel = State(initialValue: WorkoutResultsViewModel(workoutId: workoutId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let workout = viewModel.workout {
                    summary(workout)
                    filterControl
                        .padding(.top, Tokens.Spacing.loose)
                    HStack(alignment: .firstTextBaseline) {
                        Text(workout.pieces.isEmpty ? "Rowers" : "Splits against target")
                            .textStyle(Typography.sectionTitle)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: Tokens.Spacing.tight)
                        if !workout.pieces.isEmpty {
                            Text("− faster · + slower")
                                .textStyle(Typography.statLabel)
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, Tokens.Spacing.sectionTop)
                    .padding(.bottom, Tokens.Spacing.tight)

                    // One grouped list, rows divided by hairlines (decision 97, app-wide).
                    GroupedSection {
                        ForEach(Array(viewModel.shownRows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 { GroupedDivider() }
                            rowerCard(row, hasPieces: !workout.pieces.isEmpty)
                                .asButton { navigate(.coachRower(row.rower.id)) }
                        }
                    }

                    GuidedText("Showing \(viewModel.shownRows.count) of \(viewModel.rows.count).", hint: "Sessions are linked when a rower posts while the workout is showing.")
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)

                    Button("Delete workout") { isConfirmingDelete = true }
                        .buttonStyle(.rpDestructive)
                        .disabled(viewModel.isDeleting)
                        .padding(.top, Tokens.Spacing.group)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Workout", onBack: { dismiss() }) {
                HStack(spacing: Tokens.Spacing.tight) {
                    Button("Edit") { navigate(.editWorkout(viewModel.workoutId)) }
                        .buttonStyle(.rpText)
                        .disabled(viewModel.workout == nil)
                        .accessibilityLabel("Edit workout")
                    GlassIconButton(icon: .pencil, accessibilityLabel: "Notepad") { navigate(.notepad(viewModel.workoutId)) }
                }
            }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        // Back from Edit workout: show the saved changes.
        .onAppear { if hasAppeared { Task { await viewModel.load() } }; hasAppeared = true }
        .refreshable { await viewModel.load() }
        .alert("Delete \(viewModel.workout?.title ?? "this workout")?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It disappears for everyone it was set for. Sessions already linked to it stay, unlinked.")
        }
    }

    // MARK: - Summary

    private func summary(_ workout: CoachWorkout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(WorkoutRules.whenText(workout, calendar: .current))
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer(minLength: 0)
                BrandChip(text: workout.isTestDay ? "Test" : (workout.zone ?? "UT2"))
            }
            Text(workout.title)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.top, 6)
            Text(summaryLine(workout))
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
            if let description = workout.description {
                Text(description)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.top, Tokens.Spacing.tight)
            }
            HStack(alignment: .top, spacing: 4) {
                stat(viewModel.doneCount, "done")
                stat(viewModel.partlyCount, "partly")
                stat(viewModel.notYetCount, viewModel.isOver ? "absent" : "not yet")
            }
            .padding(.top, Tokens.Spacing.loose)
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    /// "Senior men, Senior women · rest 5:00 · rate 26–28".
    private func summaryLine(_ workout: CoachWorkout) -> String {
        var parts = [viewModel.audienceText]
        if let rest = WorkoutRules.restText(workout.pieces) { parts.append("rest \(rest)") }
        if let rate = WorkoutRules.rateText(workout.pieces) { parts.append("rate \(rate)") }
        return parts.joined(separator: " · ")
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .textStyle(Typography.coachStatSmall)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
            Text(label)
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var filterControl: some View {
        PillSegmentedControl(
            options: ["All \(viewModel.rows.count)", "Done", viewModel.isOver ? "Absent" : "Not yet"],
            selection: Binding(
                get: { viewModel.filter.rawValue },
                set: { viewModel.filter = WorkoutResultsViewModel.Filter(rawValue: $0) ?? .all }
            ),
            compact: true
        )
    }

    // MARK: - One rower

    private func rowerCard(_ row: WorkoutResultsViewModel.Row, hasPieces: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.Spacing.loose) {
                AvatarPlaceholder(diameter: Tokens.Size.rowerCardAvatar, name: row.rower.displayName, userId: row.rower.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.rower.displayName)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    Text(row.targetText)
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                statusChip(row.status)
            }
            if hasPieces && row.status != .notYet && row.status != .absent {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight, alignment: .leading), count: 3),
                          alignment: .leading, spacing: Tokens.Spacing.tight) {
                    ForEach(row.reps) { rep in
                        repCell(rep)
                    }
                }
                .padding(.top, Tokens.Spacing.loose)
            }
        }
        .padding(.horizontal, Tokens.Grouped.rowPadding)
        .padding(.vertical, Tokens.Spacing.tight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func repCell(_ rep: WorkoutResultsViewModel.RepCell) -> some View {
        if let split = rep.splitMs {
            VStack(alignment: .leading, spacing: 0) {
                Text(WorkoutRules.splitTenthsText(split))
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                if let target = rep.targetMs {
                    Text(WorkoutRules.deltaText(rowedMs: split, targetMs: target))
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(split <= target ? Tokens.Accent.success : Tokens.System.error)
                }
            }
        } else {
            Text("—")
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }

    @ViewBuilder
    private func statusChip(_ status: WorkoutStatus) -> some View {
        switch status {
        case .done:
            Text("Done")
                .textStyle(Typography.chip)
                .foregroundStyle(Tokens.Accent.success)
                .padding(.horizontal, 9)
                .frame(minHeight: Tokens.Size.chip)
                .background(Capsule().fill(Tokens.Accent.success.opacity(Tokens.Coaching.flagChipTint)))
        case .partly(let completed, let total):
            FlagChip(text: "\(completed) of \(total)")
        case .notYet:
            FlagChip(text: "Not yet")
        case .absent:
            FlagChip(text: "Absent", isWarning: true)
        }
    }
}
