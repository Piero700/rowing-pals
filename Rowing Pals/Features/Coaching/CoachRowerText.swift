//
//  CoachRowerText.swift
//  Rowing Pals
//

import Foundation
import PaceEngine

/// How Coaching writes a rower's numbers (one place, so the list and a rower's page agree).
enum CoachRowerText {
    /// "Novices · Coach"; their level when they're in no squad.
    static func subtitle(_ rower: CoachRower) -> String {
        var parts = rower.squadNames.isEmpty ? [rower.category.rawValue.capitalized] : rower.squadNames
        if rower.isCoach { parts.append("Coach") }
        return parts.joined(separator: " · ")
    }

    /// Kilometres: "22.0", or "45" without decimals.
    static func km(_ metres: Int, decimals: Bool = true) -> String {
        if decimals { return String(format: "%.1f", Double(metres) / 1000) }
        return metres % 1000 == 0 ? String(metres / 1000) : String(format: "%.1f", Double(metres) / 1000)
    }

    /// The Pace Engine's 2k time and how sure it is: "6:52.3 · High". The engine gives a
    /// confidence band, not a ± in seconds, so the band is what's shown.
    static func prediction(_ prediction: Prediction?) -> String {
        guard let prediction, let time = prediction.predictedTotalTimeFormatted else { return "—" }
        return "\(time) · \(band(prediction.confidenceScore))"
    }

    static func band(_ band: Prediction.ConfidenceBand) -> String {
        switch band {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .populationEstimate: "Estimate"
        case .insufficientData: "—"
        }
    }
}
