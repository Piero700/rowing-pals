//
//  CoachScoresCard.swift
//  Rowing Pals
//

import SwiftUI

/// On a rower's Feed for a few days after a workout, the scores their coach noted for them
/// (RowerCoachScores, RowerCoachScoresPosted; decision 96, NP4): the date, workout and their erg,
/// one tile per piece, and — if they haven't posted it — the line saying the coach's numbers don't
/// count and **Log your session**, which opens the normal Log flow with nothing copied across.
/// Once posted: "You posted this session · your average 1:43.6".
struct CoachScoresCard: View {
    let card: CoachNotedScores
    let onLog: () -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let tileShape = RoundedRectangle(cornerRadius: Tokens.Notepad.scoreTileRadius, style: .continuous)

    private var reps: [WorkoutPiece?] {
        NotepadRules.reps(NotepadRules.pieces(set: card.pieces, title: card.title, testKey: card.testKey))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            HStack(spacing: Tokens.Spacing.loose) {
                RPIconView(icon: .pencil, size: Tokens.Icon.small)
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Tokens.Notepad.scoresIcon, height: Tokens.Notepad.scoresIcon)
                    .background(Circle().fill(Tokens.Accent.brandSoft))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your coach noted your scores")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(subtitle)
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            tiles
            if let average = card.postedAverageMs {
                HStack(spacing: Tokens.Spacing.tight) {
                    RPIconView(icon: .check, size: Tokens.Icon.small)
                    Text("You posted this session · your average \(WorkoutRules.splitTenthsText(average))")
                }
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
            } else {
                Text("Your coach’s numbers don’t count towards your volume, pieces or PBs. Log the session yourself to count it.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                CardLinkRow(icon: .plus, title: "Log your session", action: onLog)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    /// "Tue 4 Nov · 3 × 2,000m · erg 3".
    private var subtitle: String {
        var parts: [String] = []
        if let date = WorkoutRules.day(card.workoutDate, calendar: .current) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_GB")
            formatter.dateFormat = "EEE d MMM"
            parts.append(formatter.string(from: date))
        }
        parts.append(card.title)
        if let erg = card.erg { parts.append("erg \(erg)") }
        return parts.joined(separator: " · ")
    }

    /// One tile per piece: the coach's split, "out", or "–" for a piece they didn't note.
    private var tiles: some View {
        let count = reps.count
        let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.tight),
                            count: max(1, min(count, Tokens.Notepad.scoreTilesPerRow)))
        let byIndex = Dictionary(card.scores.map { ($0.index, $0) }, uniquingKeysWith: { first, _ in first })
        return LazyVGrid(columns: columns, spacing: Tokens.Spacing.tight) {
            ForEach(0..<count, id: \.self) { index in
                let piece = byIndex[index]
                let value = piece.map { $0.satOut ? "out" : ($0.splitMs.map(WorkoutRules.splitTenthsText) ?? "–") } ?? "–"
                VStack(spacing: 2) {
                    Text(count == 1 ? "Split" : "Piece \(index + 1)")
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                    Text(value)
                        .textStyle(Typography.coachStatSmall)
                        .tabularNumerals()
                        .foregroundStyle(piece?.splitMs == nil ? Tokens.Ink.faint : Tokens.Ink.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Self.tileShape.fill(Tokens.Surface.raised))
                .accessibilityElement(children: .combine)
            }
        }
    }
}
