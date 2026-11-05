//
//  FeedChallengeCard.swift
//  Rowing Pals
//

import SwiftUI

/// A challenge or erg event on the Feed (decision 91). A challenge: its kind and days left, its name,
/// your progress and bar. An erg event: when it's on, its name and piece, and Log your piece while
/// it's open. Tapping opens its page.
struct FeedChallengeCard: View {
    let item: FeedChallengesModel.Item
    let onOpen: () -> Void
    let onLog: () -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 6) {
                    switch item {
                    case .challenge(let challenge, let progress):
                        Text("\(challenge.kind == .squads ? "Squad challenge" : "Challenge") · \(ChallengeText.when(challenge))")
                            .textStyle(Typography.kicker)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Accent.brand)
                        Text(challenge.title)
                            .textStyle(Typography.cardTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                            .multilineTextAlignment(.leading)
                        if let progress {
                            Text(progress.text)
                                .textStyle(Typography.meta)
                                .fontWeight(.semibold)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.primary)
                            ChallengeBar(fraction: progress.fraction, isMine: challenge.kind != .clubTotal, isDone: progress.isDone)
                        }
                    case .event(let event):
                        Text("Erg event · \(ChallengeText.when(event))")
                            .textStyle(Typography.kicker)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Accent.brand)
                            .lineLimit(2)
                        Text(event.title)
                            .textStyle(Typography.cardTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                            .multilineTextAlignment(.leading)
                        Text("\(event.pieceLabel) · \(ChallengeText.window(event))")
                            .textStyle(Typography.meta)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())

            if case .event(let event) = item, event.isOpenForPosting(at: Date()) {
                CardLinkRow(icon: .plus, title: "Log your \(event.pieceLabel)", action: onLog)
                .padding(.top, 4)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }
}
