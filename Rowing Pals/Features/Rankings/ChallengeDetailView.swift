//
//  ChallengeDetailView.swift
//  Rowing Pals
//

import SwiftUI

/// One challenge (decision 91). A personal target: your progress, then every rower's bar, ticked
/// when done. A club total: the club's bar and who's rowed the most of it. Squad against squad: the
/// squads on metres per rower, each opening to its rowers. Coaches, the owner, co-owners and admins
/// get Edit.
struct ChallengeDetailView: View {
    @State private var viewModel: ChallengeDetailViewModel
    @State private var openSquads: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(challengeId: UUID) {
        _viewModel = State(initialValue: ChallengeDetailViewModel(challengeId: challengeId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let challenge = viewModel.challenge {
                    content(challenge)
                } else if viewModel.hasLoaded {
                    Text(viewModel.errorMessage ?? "This challenge is no longer there.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, Tokens.Spacing.group)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Challenge") {
                dismiss()
            } trailing: {
                if viewModel.canEdit {
                    Button("Edit") { navigate(.editChallenge(viewModel.challengeId)) }
                        .buttonStyle(.rpText)
                }
            }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .challengesChanged)) { _ in
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func content(_ challenge: Challenge) -> some View {
        BrandChip(text: challenge.kind.label)
            .padding(.top, Tokens.Spacing.loose)
        Text(challenge.title)
            .textStyle(Typography.bigResult)
            .foregroundStyle(Tokens.Ink.primary)
            .padding(.top, Tokens.Spacing.tight)
        Text("\(ChallengeText.days(challenge)) · \(ChallengeText.when(challenge))")
            .textStyle(Typography.meta)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.top, 2)
        Text(explanation(challenge))
            .textStyle(Typography.bodySecondary)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.top, Tokens.Spacing.tight)

        switch challenge.kind {
        case .target: target(challenge)
        case .clubTotal: clubTotal(challenge)
        case .squads: squads
        }
    }

    private func explanation(_ challenge: Challenge) -> String {
        switch challenge.kind {
        case .target:
            "Everyone aims for \(challenge.targetM.map(ChallengeText.metres) ?? "the target") on the erg. Metres on the leaderboards count, as in Rankings."
        case .clubTotal:
            "The club rows \(challenge.targetM.map(ChallengeText.metres) ?? "the total") together. Every rower’s metres on the leaderboards count."
        case .squads:
            "Squads race on metres per rower, so a bigger squad doesn’t win by size. Metres on the leaderboards count."
        }
    }

    // MARK: - Personal target

    @ViewBuilder
    private func target(_ challenge: Challenge) -> some View {
        let target = challenge.targetM ?? 0
        if viewModel.viewerRows {
            let mine = viewModel.myMetres
            VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                Text(mine >= target ? "You’ve done it" : "You")
                    .textStyle(Typography.overline)
                    .foregroundStyle(mine >= target ? Tokens.Accent.success : Tokens.Ink.secondary)
                Text("\(ChallengeText.metres(mine)) of \(ChallengeText.metres(target))")
                    .textStyle(Typography.cardTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                ChallengeBar(fraction: Double(mine) / Double(max(target, 1)), isMine: true, isDone: mine >= target)
            }
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
            .padding(.top, Tokens.Spacing.loose)
        }
        sectionTitle("Rowers", trailing: "\(viewModel.doneCount) of \(viewModel.targetRows.count) done")
        listCard {
            ForEach(Array(viewModel.targetRows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { divider }
                personRow(place: index + 1, name: row.standing.displayName, userId: row.standing.userId,
                          value: ChallengeText.metres(row.standing.metres), fraction: row.progress, isDone: row.isDone)
            }
        }
    }

    // MARK: - Club total

    @ViewBuilder
    private func clubTotal(_ challenge: Challenge) -> some View {
        let target = challenge.targetM ?? 0
        let total = viewModel.total
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            Text(total >= target ? "Done together" : "The club")
                .textStyle(Typography.overline)
                .foregroundStyle(total >= target ? Tokens.Accent.success : Tokens.Ink.secondary)
            Text("\(ChallengeText.metres(total)) of \(ChallengeText.metres(target))")
                .textStyle(Typography.cardTitle)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
            ChallengeBar(fraction: Double(total) / Double(max(target, 1)), isDone: total >= target)
            if viewModel.viewerRows {
                Text("Your share: \(ChallengeText.metres(viewModel.myMetres))")
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        .padding(.top, Tokens.Spacing.loose)

        let rows = viewModel.contributors
        sectionTitle("Who’s rowed it", trailing: "\(rows.count) rower\(rows.count == 1 ? "" : "s")")
        if rows.isEmpty {
            Text("Nobody’s rowed any of it yet.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
        } else {
            let top = rows.first?.metres ?? 1
            listCard {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { divider }
                    personRow(place: index + 1, name: row.displayName, userId: row.userId,
                              value: ChallengeText.metres(row.metres), fraction: Double(row.metres) / Double(max(top, 1)), isDone: false)
                }
            }
        }
    }

    // MARK: - Squad against squad

    @ViewBuilder
    private var squads: some View {
        let rows = viewModel.squadRows
        let best = rows.first?.perRowerM ?? 1
        sectionTitle("Squads", trailing: nil)
        VStack(spacing: Tokens.Spacing.tight) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, squad in
                let isMine = squad.members.contains { $0.userId == viewModel.viewerId }
                let isOpen = openSquads.contains(squad.id)
                VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                    Button {
                        if isOpen { openSquads.remove(squad.id) } else { openSquads.insert(squad.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.tight) {
                                Text("\(index + 1)")
                                    .textStyle(Typography.cardTitle)
                                    .tabularNumerals()
                                    .foregroundStyle(index == 0 ? Tokens.Accent.rank : Tokens.Ink.primary)
                                Text(squad.name)
                                    .textStyle(Typography.cardTitle)
                                    .foregroundStyle(isMine ? Tokens.Accent.brand : Tokens.Ink.primary)
                                Spacer(minLength: 0)
                                Text("\(ChallengeText.metres(squad.perRowerM)) a rower")
                                    .textStyle(Typography.rowTitle)
                                    .tabularNumerals()
                                    .foregroundStyle(Tokens.Ink.primary)
                            }
                            ChallengeBar(fraction: Double(squad.perRowerM) / Double(max(best, 1)), isMine: isMine)
                            Text("\(ChallengeText.metres(squad.totalM)) in all · \(squad.members.count) rower\(squad.members.count == 1 ? "" : "s")\(isMine ? " · your squad" : "")")
                                .textStyle(Typography.meta)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                    .accessibilityHint(isOpen ? "Hides its rowers" : "Shows its rowers")
                    if isOpen {
                        ForEach(squad.members) { member in
                            HStack {
                                Text(member.displayName)
                                    .textStyle(Typography.meta)
                                    .foregroundStyle(member.userId == viewModel.viewerId ? Tokens.Accent.brand : Tokens.Ink.primary)
                                Spacer(minLength: 0)
                                Text(ChallengeText.metres(member.metres))
                                    .textStyle(Typography.meta)
                                    .tabularNumerals()
                                    .foregroundStyle(Tokens.Ink.secondary)
                            }
                        }
                    }
                }
                .padding(Tokens.Spacing.card)
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
            }
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionTitle(title)
            if let trailing {
                Text(trailing)
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .fixedSize()
            }
        }
        .padding(.top, Tokens.Spacing.group)
    }

    private var divider: some View {
        Rectangle().fill(Tokens.Surface.line).frame(height: Tokens.Grouped.hairline)
    }

    private func listCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .clipShape(Self.cardShape)
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    private func personRow(place: Int, name: String, userId: UUID, value: String, fraction: Double, isDone: Bool) -> some View {
        let isMine = userId == viewModel.viewerId
        return Button {
            navigate(.profile(userId))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: Tokens.Spacing.tight) {
                    Text("\(place)")
                        .textStyle(Typography.rowTitle)
                        .tabularNumerals()
                        .foregroundStyle(place == 1 ? Tokens.Accent.rank : Tokens.Ink.secondary)
                        .frame(minWidth: 22, alignment: .leading)
                    Text(isMine ? "You" : name)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(isMine ? Tokens.Accent.brand : Tokens.Ink.primary)
                        .lineLimit(1)
                    if isDone {
                        RPIconView(icon: .checkCircle, size: Tokens.Icon.small)
                            .foregroundStyle(Tokens.Accent.success)
                            .accessibilityLabel("Done")
                    }
                    Spacer(minLength: 0)
                    Text(value)
                        .textStyle(Typography.rowTitle)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                }
                ChallengeBar(fraction: fraction, isMine: isMine, isDone: isDone)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
    }
}
