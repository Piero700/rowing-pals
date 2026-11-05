//
//  WorkoutCard.swift
//  Rowing Pals
//

import SwiftUI

/// One set workout on Coaching's Workouts tab (CoachWorkouts): when, its zone or "Test", the
/// title, who it's for, and how many have done it, with a bar that turns green when everyone has.
struct WorkoutCard: View {
    let item: WorkoutsViewModel.Item
    let isToday: Bool
    /// False when the caller draws the card around this and more (today's card, which has
    /// Open notepad inside it under the bar, decision 96).
    var drawsCard = true

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        let workout = item.workout
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.Spacing.tight) {
                Text(WorkoutRules.whenText(workout, calendar: .current))
                    .font(isToday ? Typography.meta.font.weight(.semibold) : Typography.meta.font)
                    .tabularNumerals()
                    .foregroundStyle(isToday ? Tokens.Accent.brand : Tokens.Ink.secondary)
                Spacer(minLength: 0)
                BrandChip(text: workout.isTestDay ? "Test" : (workout.zone ?? "UT2"))
            }
            Text(workout.title)
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.top, 6)
            Text(item.audienceText)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
            HStack {
                Text("Completed")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer(minLength: 0)
                Text("\(item.done) of \(item.total)")
                    .font(Typography.meta.font.weight(.semibold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
            }
            .padding(.top, Tokens.Spacing.loose)
            .padding(.bottom, 6)
            GeometryReader { geometry in
                let fraction = item.total > 0 ? Double(item.done) / Double(item.total) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.Surface.raised)
                    Capsule()
                        .fill(item.total > 0 && item.done == item.total ? Tokens.Accent.success : Tokens.Ink.primary)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: Tokens.Size.targetBar)
            .accessibilityHidden(true)
        }
        .padding(Tokens.Spacing.card)
        .background { if drawsCard { Self.card } }
        .accessibilityElement(children: .combine)
    }

    /// The card's ground and edge, for a caller that draws it around more than this.
    @ViewBuilder static var card: some View {
        cardShape.fill(Tokens.Surface.card)
            .overlay { cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }
}
