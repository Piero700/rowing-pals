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

    /// The Pace Engine's 2k time and its likely range (engine v1.5): "7:20 ±9s".
    static func prediction(_ prediction: Prediction?) -> String {
        guard let time = predictedTime(prediction) else { return "—" }
        guard let range = range(prediction) else { return time }
        return "\(time) \(range)"
    }

    /// The predicted time to the second, as the canvas shows it: "7:20".
    static func predictedTime(_ prediction: Prediction?) -> String? {
        guard let seconds = prediction?.predictedTotalTimeSeconds else { return nil }
        let whole = Int(seconds.rounded())
        let hours = whole / 3600, minutes = (whole % 3600) / 60, rest = whole % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// "±9s": the engine's range over the whole piece, to the second (at least 1).
    static func range(_ prediction: Prediction?) -> String? {
        guard let seconds = prediction?.predictedTotalTimeRangeSeconds else { return nil }
        return "±\(max(1, Int(seconds.rounded())))s"
    }
}
