//
//  TodaysWorkoutCard.swift
//  Rowing Pals
//

import SwiftUI

/// Today's workout at the top of the feed (RowerFeedCoaching, decision 39): what the coach set,
/// who it's from and for, the rate, the rower's own target split and the pieces, and Log it.
/// The description shows too (the canvas leaves it out; it's what the coach asked for).
struct TodaysWorkoutCard: View {
    let today: TodaysWorkout
    let onLog: () -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Today’s workout")
                    .textStyle(Typography.kicker)
                    .foregroundStyle(Tokens.Accent.brand)
                Spacer(minLength: 0)
                BrandChip(text: today.zoneText)
            }
            Text(today.workout.title)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.top, 6)
            Text(today.fromText)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
            if let description = today.workout.description {
                Text(description)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.top, Tokens.Spacing.tight)
            }
            let figures = self.figures
            if !figures.isEmpty {
                HStack(spacing: Tokens.Spacing.screen) {
                    ForEach(figures, id: \.label) { figure in
                        (Text("\(figure.label) ").font(Typography.meta.font).foregroundStyle(Tokens.Ink.secondary)
                         + Text(figure.value).font(Typography.meta.font.weight(.semibold)).foregroundStyle(Tokens.Ink.primary))
                            .tabularNumerals()
                    }
                }
                .padding(.top, Tokens.Spacing.loose)
            }
            Button("Log it", action: onLog)
                .buttonStyle(.rpPill(isOn: true))
                .padding(.top, Tokens.Spacing.loose)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.card)
        .background {
            Self.cardShape.fill(
                LinearGradient(
                    stops: [.init(color: Tokens.Accent.brandSoft, location: 0),
                            .init(color: Tokens.Surface.card, location: 0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .background(Self.cardShape.fill(Tokens.Surface.card))
        }
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        .accessibilityElement(children: .combine)
    }

    /// Rate, split and pieces, whichever the workout has.
    private var figures: [(label: String, value: String)] {
        var result: [(label: String, value: String)] = []
        if let rate = today.rateText { result.append(("Rate", rate)) }
        if let split = today.targetSplitMs { result.append(("Split", WorkoutRules.splitText(split))) }
        if let pieces = today.piecesText { result.append(("Pieces", pieces)) }
        return result
    }
}
