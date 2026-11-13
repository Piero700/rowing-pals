//
//  PredictionDetailView.swift
//  Rowing Pals
//

import PaceEngine
import SwiftUI

/// "How we got this" (decision 31): a prediction's arithmetic top to bottom — anchor, the
/// corrections that turn it into a 2k split, then the projection and volume that turn that into
/// the predicted split — followed by why the confidence is what it is and how to raise it.
/// Weight-adjusted and age-graded scores are never shown (decision 30). With no prediction yet
/// it explains how one is worked out and what unlocks it (ⓘ always opens this, 2026-10-15).
struct PredictionDetailView: View {
    /// "2k", "5k".
    let title: String
    let prediction: Prediction?

    @Environment(\.dismiss) private var dismiss

    private struct Line: Identifiable {
        let label: String
        let value: String
        var isResult = false
        var id: String { label }
    }

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            content
        }
        .scrollIndicators(.hidden)
        .background(Tokens.Base.ground)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// Everything inside the scroll view.
    var content: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("\(title) prediction")
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.rpText)
                }

                if let prediction, PredictionService.isShowable(prediction) {
                    headline(prediction)
                    SectionTitle("How we got this")
                    card(lines(prediction))
                    if let held = prediction.recommendations.first(where: PredictionCard.isHeldSplitNote) {
                        Text(held)
                            .textStyle(Typography.meta)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.horizontal, 4)
                            .padding(.top, Tokens.Spacing.tight)
                    }
                    SectionTitle("Confidence")
                    card(confidenceLines(prediction))
                } else {
                    Text(PredictionCard.unlockText)
                        .textStyle(Typography.bodyV3)
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(.top, Tokens.Spacing.loose)
                    SectionTitle("How it works")
                    Text(Self.howItWorks)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Tokens.Spacing.card)
                        .background(Self.cardShape.fill(Tokens.Surface.card))
                        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
                }

                if !advice.isEmpty {
                    SectionTitle("How to improve it")
                    VStack(alignment: .leading, spacing: Tokens.Spacing.gap) {
                        ForEach(advice, id: \.self) { line in
                            Text(line)
                                .textStyle(Typography.meta)
                                .foregroundStyle(Tokens.Ink.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(Tokens.Spacing.card)
                    .background(Self.cardShape.fill(Tokens.Surface.card))
                    .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
                }

                Text("Worked out on your phone from every erg session in the last 30 days, and your all-out pieces from the last 90.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.top, Tokens.Spacing.loose)
                    .guidance()
            }
            .padding(Tokens.Spacing.screen)
    }

    /// What the engine does, for the sheet with no prediction to explain yet.
    static let howItWorks = "Your predicted times come from every erg session in the last 30 days, worked out on your phone. Every all-out piece counts, closer distances and newer pieces most; without one, all your steady rows count together, read at their zone's usual rate. Steady rows that have got faster since your last all-out piece take part of that off, and so does training volume rowed since it. That 2k split is taken out to the distance with Paul's Law, using how much you slow per doubling of distance once your all-out pieces from the last 90 days show it. A prediction is never slower than a split you've already held for longer."

    private func headline(_ prediction: Prediction) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(prediction.predictedTotalTimeFormatted ?? "—")
                .textStyle(Typography.bigResult)
                .tabularNumerals()
                .foregroundStyle(Tokens.Accent.records)
            Text("\(prediction.predictedSplitFormatted ?? "—") /500m · \(PredictionCard.bandText(prediction.confidenceScore))")
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(.top, Tokens.Spacing.loose)
    }

    // MARK: - The arithmetic

    private func lines(_ prediction: Prediction) -> [Line] {
        let parts = prediction.components
        var lines: [Line] = []
        if let anchor = prediction.anchor, let split = parts.anchorSplit {
            lines.append(.init(label: anchorLabel(anchor), value: Self.split(split)))
        }
        if let value = parts.paulAdjustment {
            lines.append(.init(label: "Distance correction (Paul's Law)", value: Self.signed(value)))
        }
        if let value = parts.intensityOffset, let tier = prediction.anchor?.tier {
            lines.append(.init(label: "Zone correction (\(tier.rawValue) to all-out)", value: Self.signed(value)))
        }
        if let value = parts.rpeCorrection, value != 0 {
            lines.append(.init(label: "How hard it felt", value: Self.signed(value)))
        }
        if let value = parts.rateCorrection, value != 0 {
            lines.append(.init(label: "Stroke rate, read at the zone's usual rate", value: Self.signed(value)))
        }
        if let value = parts.twoKEquivalent {
            lines.append(.init(label: "Your 2k split", value: Self.split(value), isResult: true))
        }
        if let value = parts.projectionToTarget, value != 0 {
            lines.append(.init(label: Self.projectionLabel(title, prediction.personalPaul), value: Self.signed(value)))
        }
        if let value = parts.weightTrendCorrection, value != 0 {
            lines.append(.init(label: "Bodyweight change", value: Self.signed(value)))
        }
        if let value = parts.steadyChangeAdjustment, value != 0 {
            lines.append(.init(label: "Your steady rows since your last all-out piece", value: Self.signed(value)))
        }
        if let value = parts.volumeModifier {
            lines.append(.init(label: "Training volume, last 30 days", value: Self.signed(value)))
        }
        if let value = parts.heldSplitAdjustment, value != 0 {
            lines.append(.init(label: "A split you've already held for longer", value: Self.signed(value)))
        }
        if let value = parts.clampAdjustment, value != 0 {
            lines.append(.init(label: "Held to a physiological limit", value: Self.signed(value)))
        }
        if let split = prediction.predictedSplitFormatted {
            lines.append(.init(label: "Predicted split", value: "\(split) /500m", isResult: true))
        }
        if let total = prediction.predictedTotalTimeFormatted {
            lines.append(.init(label: "Predicted \(title) time", value: total, isResult: true))
        }
        return lines
    }

    private func confidenceLines(_ prediction: Prediction) -> [Line] {
        var lines = prediction.confidenceFactors.enumerated().map { index, factor in
            Line(label: factor.label, value: index == 0 ? "\(factor.delta)" : Self.signedInt(factor.delta))
        }
        lines.append(.init(label: PredictionCard.bandText(prediction.confidenceScore),
                           value: "\(prediction.confidenceNumeric) of 100", isResult: true))
        return lines
    }

    private var advice: [String] {
        guard let prediction else { return [] }
        let advice = PredictionService.isShowable(prediction) ? prediction.recommendations : Array(prediction.recommendations.prefix(1))
        // The held-split line sits under "How we got this", not with the advice.
        return advice.filter { !PredictionCard.isHeldSplitNote($0) }
    }

    /// "Paul's Law out to 5k", naming the rower's own rate when their all-out pieces set one
    /// (engine v1.7, §5.21).
    private static func projectionLabel(_ title: String, _ paul: Prediction.PersonalPaulSummary?) -> String {
        guard let paul, paul.fitted else { return "Paul's Law out to \(title)" }
        return "Paul's Law out to \(title) (yours: \(String(format: "%.1f", paul.secondsPerDoubling)) s per doubling)"
    }

    /// Which session(s) the prediction rests on.
    private func anchorLabel(_ anchor: Prediction.AnchorSummary) -> String {
        let zone = anchor.tier.rawValue
        if anchor.method == "zone_blend" {
            // Every steady piece together (v1.7, §5.17); the middle one is shown.
            let count = anchor.sessionIds.count
            let distance = Int(anchor.effectiveDistanceM).formattedWithGrouping
            return "Your steady rows (\(count) piece\(count == 1 ? "" : "s")), middle one: \(zone) \(distance)m"
        }
        if anchor.method == "duration_weighted_median" {
            let count = anchor.sessionIds.count
            return "Your \(zone) rows (\(count) session\(count == 1 ? "" : "s")), typical split"
        }
        let distance = Int(anchor.effectiveDistanceM).formattedWithGrouping
        return "Your \(zone) \(distance)m, \(Self.shortDate(anchor.date))"
    }

    private func card(_ lines: [Line]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.gap) {
                    Text(line.label)
                        .textStyle(line.isResult ? Typography.rowTitle : Typography.detail)
                        .tabularNumerals()
                        .foregroundStyle(line.isResult ? Tokens.Ink.primary : Tokens.Ink.secondary)
                    Spacer(minLength: 0)
                    Text(line.value)
                        .textStyle(line.isResult ? Typography.rowTitle : Typography.detail)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                }
                .padding(.horizontal, Tokens.Spacing.card)
                .padding(.vertical, Tokens.Spacing.loose)
                if index < lines.count - 1 {
                    Rectangle().fill(Tokens.Surface.line).frame(height: Tokens.Grouped.hairline)
                }
            }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .clipShape(Self.cardShape)
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    // MARK: - Formatting

    private static func split(_ seconds: Double) -> String {
        "\(formatSeconds(seconds) ?? "—") /500m"
    }

    /// "+2.5 s", "−8.0 s".
    private static func signed(_ seconds: Double) -> String {
        let magnitude = String(format: "%.1f s", abs(seconds))
        return seconds < 0 ? "−\(magnitude)" : "+\(magnitude)"
    }

    private static func signedInt(_ value: Int) -> String {
        value < 0 ? "−\(abs(value))" : "+\(value)"
    }

    /// "2026-09-08" → "8 Sep".
    private static func shortDate(_ iso: String) -> String {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return iso }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
