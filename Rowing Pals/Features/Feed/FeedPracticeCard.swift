//
//  FeedPracticeCard.swift
//  Rowing Pals
//

import SwiftUI

/// The rower's next practice, under today's workout on the Feed (RowerFeedCoaching; decision 68):
/// its day, "Erg · 06:30", where and who for — tap for the practice — and Available · Can't.
struct FeedPracticeCard: View {
    let practice: Practice
    let answer: PracticeAnswer?
    let squadText: String?
    var errorMessage: String?
    let onOpen: () -> Void
    let onAnswer: (PracticeAnswer) -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            Button(action: onOpen) {
                HStack(spacing: Tokens.Spacing.loose) {
                    DateBlock(date: practice.startsAt)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(practice.displayTitle) · \(CalendarRules.time(practice.startsAt, calendar: .current))")
                            .textStyle(Typography.rowTitle)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.primary)
                        if let detail {
                            Text(detail)
                                .textStyle(Typography.meta)
                                .foregroundStyle(Tokens.Ink.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .textStyle(Typography.pill)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())
            AnswerControl(answer: answer, isEnabled: CalendarRules.canAnswer(practice, now: Date()), isWide: true, onChange: onAnswer)
            if let errorMessage {
                Text(errorMessage)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.System.error)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    /// "UEA boathouse · Senior men".
    private var detail: String? {
        let parts = [practice.place, squadText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
