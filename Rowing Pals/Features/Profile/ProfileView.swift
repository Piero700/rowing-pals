//
//  ProfileView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 7 — profile, built in the design brief's order: (a) header, (b)
/// streak, (c) season strip, (d) PB board, (e) weekly volume bars, (f)
/// consistency calendar, (g) photo grid.
struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var expandedTest: StandardTest?
    @State private var isShowingSettings = false
    /// Redesign phase B — per-device display preference, not synced to
    /// the profile. See DesignSystem/DistanceUnit.swift.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres

    var body: some View {
        // Direct ScrollView child, same constraint as FeedView — see its comment.
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                streakBlock
                seasonStrip

                sectionLabel("PERSONAL BESTS")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                    ForEach(viewModel.pbTiles) { tile in
                        pbTile(tile)
                            .onTapGesture {
                                guard tile.hasResult else { return }
                                expandedTest = tile.test
                            }
                    }
                }

                sectionLabel("WEEKLY VOLUME")
                WeeklyVolumeChart(weeks: viewModel.weeklyVolumes, targetM: viewModel.weeklyTargetM)
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Tokens.Ink.primary.opacity(0.05))
                    }

                sectionLabel("CONSISTENCY")
                ConsistencyCalendarView(days: viewModel.consistencyDays)
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Tokens.Ink.primary.opacity(0.05))
                    }

                sectionLabel("POSTS")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                    ForEach(viewModel.photos) { photo in
                        photoTile(photo)
                    }
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 14)
        }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .fullScreenCover(item: $expandedTest) { test in
            PBProgressionView(test: test)
        }
        .sheet(isPresented: $isShowingSettings, onDismiss: { Task { await viewModel.load() } }) {
            SettingsView()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AvatarPlaceholder(diameter: 52)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(viewModel.displayName)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                    if !viewModel.categoryLabel.isEmpty {
                        Text(viewModel.categoryLabel)
                            .textStyle(Typography.label)
                            .textCase(nil)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Tokens.Ink.primary.opacity(0.12))
                            }
                    }
                }
                if let clubName = viewModel.clubName {
                    Text(clubName)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            Spacer()
            // Opens SettingsView (task 17: support contact + terms only —
            // task 18 adds edit-profile, novice/senior, weekly target,
            // sign out and Delete Account to the same screen).
            Button {
                isShowingSettings = true
            } label: {
                Text("Edit")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Tokens.Ink.primary.opacity(0.09))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(viewModel.streakDays)")
                    .font(.system(size: 40, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("day streak")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            // Filled pips are spent rest days, hollow ones remain — neutral
            // information either way, never red or a warning (CLAUDE.md /
            // design brief: a missed day covered by a rest day is not a
            // failure state).
            HStack(spacing: 6) {
                ForEach(0..<viewModel.restDaysAllowedPerWeek, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.restDaysUsedThisWeek ? Tokens.Ink.primary.opacity(0.45) : Color.clear)
                        .overlay {
                            Circle().strokeBorder(Tokens.Ink.primary.opacity(0.35), lineWidth: 1.5)
                        }
                        .frame(width: 9, height: 9)
                }
                Text(restDaysCaption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(16)
        .glassSurface(cornerRadius: 22)
    }

    private var restDaysCaption: String {
        let remaining = max(0, viewModel.restDaysAllowedPerWeek - viewModel.restDaysUsedThisWeek)
        return "\(remaining) rest day\(remaining == 1 ? "" : "s") left this week"
    }

    private var seasonStrip: some View {
        HStack {
            StatColumn(label: seasonDistanceLabel, value: viewModel.seasonTotalDistanceM.formattedDistance(unit: distanceUnit), alignment: .center)
                .frame(maxWidth: .infinity)
            StatColumn(label: "SESSIONS", value: "\(viewModel.seasonSessionCount)", alignment: .center)
                .frame(maxWidth: .infinity)
            StatColumn(label: "LONGEST STREAK", value: "\(viewModel.longestStreakDays)", alignment: .center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.07))
        }
    }

    /// "METRES" only describes the value while the preference is metres —
    /// matches the season total's own unit once it's switched to km.
    private var seasonDistanceLabel: String {
        distanceUnit == .metres ? "METRES" : "KILOMETRES"
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.label)
            .foregroundStyle(Tokens.Ink.secondary)
    }

    private func pbTile(_ tile: ProfileViewModel.PBTile) -> some View {
        Group {
            if tile.hasResult {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tile.test.label.uppercased())
                        .textStyle(Typography.label)
                        .foregroundStyle(Tokens.Ink.secondary)
                    Text(tile.displayValue ?? "—")
                        .font(.system(size: 19, weight: .bold))
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                    if let split = tile.splitDisplay {
                        Text(split)
                            .font(.system(size: 11.5))
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        if tile.isRecentPB {
                            Circle().fill(Tokens.Accent.records).frame(width: 5, height: 5)
                        }
                        Text(tile.dateDisplay ?? "")
                            .font(.system(size: 10.5))
                            .tabularNumerals()
                            .foregroundStyle(tile.isRecentPB ? Tokens.Accent.records : Tokens.Ink.secondary.opacity(0.7))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(minHeight: 96, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(tile.isRecentPB ? Tokens.Accent.records.opacity(0.09) : Tokens.Ink.primary.opacity(0.07))
                }
                .overlay {
                    if tile.isRecentPB {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Tokens.Accent.records.opacity(0.3), lineWidth: 1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tile.test.label.uppercased())
                        .textStyle(Typography.label)
                        .foregroundStyle(Tokens.Ink.secondary.opacity(0.7))
                    Text("—")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Tokens.Ink.secondary.opacity(0.5))
                    Spacer(minLength: 0)
                    Text("Have a crack")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Tokens.Ink.secondary.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(minHeight: 96, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Tokens.Ink.primary.opacity(0.14), lineWidth: 1.5)
                }
            }
        }
    }

    private func photoTile(_ photo: ProfileViewModel.ProfilePhoto) -> some View {
        CachedAsyncImage(url: viewModel.photoURL(for: photo.monitorPath)) {
            PhotoPlaceholder(cornerRadius: 12)
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(photo.distanceM.formattedDistance(unit: distanceUnit))
                .font(.system(size: 10, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .padding(6)
        }
    }
}

#Preview {
    ProfileView()
}
