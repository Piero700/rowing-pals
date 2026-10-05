//
//  PredictionCard.swift
//  Rowing Pals
//

import PaceEngine
import SwiftUI

/// A Pace Engine prediction on Profile (decision 31), in the v3 estimate card's place and look:
/// the predicted time, its split and confidence band, and the engine's top advice. With no
/// prediction yet it says what would unlock one. ⓘ opens "How we got this".
struct PredictionCard: View {
    /// "2k", "5k".
    let title: String
    let prediction: Prediction?
    let isLoading: Bool
    let onExplain: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.estimate, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(title) · Predicted today")
                    .textStyle(Typography.cardOverline)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer()
                Button(action: onExplain) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Tokens.Accent.records)
                        .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
                .disabled(prediction == nil)
                .accessibilityLabel("How we got this")
            }
            if let prediction, PredictionService.isShowable(prediction) {
                Text(prediction.predictedTotalTimeFormatted ?? "—")
                    .textStyle(Typography.bigResult)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Accent.records)
                Text("\(prediction.predictedSplitFormatted ?? "—") /500m · \(Self.bandText(prediction.confidenceScore))")
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.top, 2)
                if let advice = prediction.recommendations.first {
                    Text(advice)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, 6)
                }
            } else {
                Text("—")
                    .textStyle(Typography.bigResult)
                    .foregroundStyle(Tokens.Accent.records)
                Text(emptyText)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(shape.fill(Tokens.Accent.recordsSoft))
        .overlay { shape.strokeBorder(Tokens.Accent.records.opacity(0.3), lineWidth: 1) }
    }

    /// What to say when there's no number to show.
    private var emptyText: String {
        guard let prediction else {
            return isLoading ? "Working out your prediction…" : "Couldn't work out a prediction just now."
        }
        if prediction.confidenceScore == .insufficientData, let advice = prediction.recommendations.first {
            return advice
        }
        return Self.unlockText
    }

    static let unlockText = "Log a few erg sessions — ideally one hard effort — and your prediction appears here."

    static func bandText(_ band: Prediction.ConfidenceBand) -> String {
        switch band {
        case .high: "High confidence"
        case .medium: "Medium confidence"
        case .low: "Low confidence"
        case .populationEstimate: "Based on people like you"
        case .insufficientData: "Not enough data"
        }
    }
}
