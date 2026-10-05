//
//  RowerCard.swift
//  Rowing Pals
//

import PaceEngine
import SwiftUI

/// One rower on Coaching's Rowers list (CoachRowers): who they are and their squads, this
/// week's km against their target with a bar (red while behind the pro-rata target, decision
/// 43), sessions, their 2k PB, the Pace Engine's 2k prediction, and any flags.
///
/// Attendance (the canvas's right-hand figure) arrives with practices in Phase 3.
struct RowerCard: View {
    let rower: CoachRower

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.Spacing.loose) {
                AvatarPlaceholder(diameter: Tokens.Size.rowerCardAvatar, name: rower.displayName, userId: rower.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rower.displayName)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    Text(CoachRowerText.subtitle(rower))
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline) {
                (Text(CoachRowerText.km(rower.weekMetres))
                    .font(Typography.meta.font.weight(.semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                 + Text(" / \(CoachRowerText.km(rower.weeklyTargetM, decimals: false)) km this week")
                    .font(Typography.meta.font)
                    .foregroundStyle(Tokens.Ink.secondary))
                    .tabularNumerals()
                Spacer(minLength: Tokens.Spacing.tight)
                Text("\(rower.weekSessions) session\(rower.weekSessions == 1 ? "" : "s")")
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.top, 14)
            .padding(.bottom, 6)

            TargetBar(metres: rower.weekMetres, target: rower.weeklyTargetM, isBehind: rower.isBehindTarget)

            HStack(alignment: .firstTextBaseline) {
                (Text("2k PB ").font(Typography.meta.font).foregroundStyle(Tokens.Ink.secondary)
                 + Text(rower.twoKBestMs.map(\.formattedDurationMs) ?? "—")
                    .font(Typography.meta.font.weight(.semibold))
                    .foregroundStyle(Tokens.Ink.primary))
                    .tabularNumerals()
                Spacer(minLength: Tokens.Spacing.tight)
                (Text("Predicted ").font(Typography.meta.font).foregroundStyle(Tokens.Ink.secondary)
                 + Text(CoachRowerText.prediction(rower.prediction))
                    .font(Typography.meta.font.weight(.semibold))
                    .foregroundStyle(Tokens.Accent.records))
                    .tabularNumerals()
            }
            .padding(.top, Tokens.Spacing.loose)

            if !rower.flags.isEmpty {
                WrapLayout(spacing: 6) {
                    ForEach(rower.flags, id: \.self) { flag in
                        FlagChip(text: flag.chipText, isWarning: flag.isWarning)
                    }
                }
                .padding(.top, Tokens.Spacing.loose)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}
