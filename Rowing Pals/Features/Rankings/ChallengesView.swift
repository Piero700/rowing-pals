//
//  ChallengesView.swift
//  Rowing Pals
//

import SwiftUI

/// Rankings → Challenges (decision 91): the club's challenges and erg events — On now (with your
/// progress), Coming up and Finished — each opening its page; the club's coaches, owner, co-owners
/// and admins also get New challenge and New erg event.
struct ChallengesView: View {
    @Binding var mode: RankingsMode
    var reselects = 0

    @State private var viewModel = ChallengesViewModel()
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RankingsHeader(mode: $mode)

                if viewModel.canSet {
                    HStack(spacing: Tokens.Spacing.tight) {
                        Button { navigate(.newChallenge) } label: { Label("New challenge", icon: .plus) }
                            .buttonStyle(.rpGlass)
                        Button { navigate(.newErgEvent) } label: { Label("New erg event", icon: .plus) }
                            .buttonStyle(.rpGlass)
                    }
                    .padding(.top, Tokens.Spacing.loose)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }

                if !viewModel.hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if !viewModel.hasClub {
                    emptyText("Join a club to take part in its challenges and erg events.")
                } else if viewModel.onNow.isEmpty && viewModel.comingUp.isEmpty && viewModel.finished.isEmpty {
                    emptyText(viewModel.canSet
                              ? "No challenges yet. Set one — a personal target, a club total or squad against squad — or an erg event like a club 2k day."
                              : "No challenges yet. Your coaches and club admins set them; they show here and on your Feed.")
                } else {
                    section("On now", viewModel.onNow)
                    section("Coming up", viewModel.comingUp)
                    section("Finished", viewModel.finished)
                }

                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
        }
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) { await viewModel.load() }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .challengesChanged)) { _ in
            Task { await viewModel.load() }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.group)
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [ChallengesViewModel.Item]) -> some View {
        if !items.isEmpty {
            SectionTitle(title)
                .padding(.top, Tokens.Spacing.group)
            VStack(spacing: Tokens.Spacing.tight) {
                ForEach(items) { item in
                    switch item {
                    case .challenge(let challenge): challengeCard(challenge)
                    case .event(let event): eventCard(event)
                    }
                }
            }
        }
    }

    private func challengeCard(_ challenge: Challenge) -> some View {
        Button {
            navigate(.challenge(challenge.id))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    BrandChip(text: challenge.kind.label)
                    Spacer(minLength: 0)
                    Text(ChallengeText.when(challenge))
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                Text(challenge.title)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .multilineTextAlignment(.leading)
                Text(subtitle(challenge))
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                if let progress = viewModel.progress(in: challenge) {
                    Text(progress.text)
                        .textStyle(Typography.meta)
                        .fontWeight(.semibold)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(.top, 4)
                    ChallengeBar(fraction: progress.fraction, isMine: challenge.kind != .clubTotal, isDone: progress.isDone)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .contentShape(Self.cardShape)
        }
        .buttonStyle(IconPressStyle())
    }

    /// "1 – 30 Nov · 100,000m each", "… · 2,000.0km together", "… · 3 squads".
    private func subtitle(_ challenge: Challenge) -> String {
        let goal: String
        switch challenge.kind {
        case .target: goal = challenge.targetM.map { "\(ChallengeText.metres($0)) each" } ?? ""
        case .clubTotal: goal = challenge.targetM.map { "\(ChallengeText.metres($0)) together" } ?? ""
        case .squads: goal = "\(challenge.squadIds.count) squads"
        }
        return "\(ChallengeText.days(challenge)) · \(goal)"
    }

    private func eventCard(_ event: ErgEvent) -> some View {
        Button {
            navigate(.ergEvent(event.id))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    BrandChip(text: "Erg event · \(event.pieceLabel)")
                    Spacer(minLength: 0)
                    Text(ChallengeText.when(event))
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
                Text(event.title)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .multilineTextAlignment(.leading)
                Text(ChallengeText.window(event))
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .contentShape(Self.cardShape)
        }
        .buttonStyle(IconPressStyle())
    }
}
