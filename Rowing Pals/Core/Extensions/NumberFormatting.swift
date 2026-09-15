//
//  NumberFormatting.swift
//  Rowing Pals
//

import Foundation

/// Durations and distances are stored as plain milliseconds/metres
/// everywhere (CLAUDE.md — "format only at the view layer"). These are that
/// one place: turning stored numbers into what a rower reads, and — for the
/// review sheet's editable fields — back again.
extension Int {
    /// "M:SS.d" under an hour, "H:MM:SS" at or beyond — matches how the PM5
    /// itself switches format past 59:59.
    var formattedDurationMs: String {
        let totalDeciseconds = self / 100
        let deciseconds = totalDeciseconds % 10
        let totalSeconds = totalDeciseconds / 10
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let hours = totalMinutes / 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d.%d", minutes, seconds, deciseconds)
    }

    /// Grouped thousands, e.g. "16,000" — UI copy only, never the stored value.
    var formattedWithGrouping: String {
        Self.groupingFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    private static let groupingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()
}

extension Double {
    /// "19" for a whole stroke rate, "19.5" when it isn't.
    var formattedRate: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
}

/// Parses user-typed duration text back to milliseconds — the inverse of
/// `Int.formattedDurationMs`, used by the review sheet's editable fields.
/// A separate, simpler parser from `MonitorParser`'s: that one has to absorb
/// OCR-specific noise (a misread comma decimal, a dropped leading digit);
/// this one only has to read what a person actually typed.
enum DurationParsing {
    static func parseMs(_ text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: ":", omittingEmptySubsequences: false)

        switch parts.count {
        case 3:
            guard let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
            let secondsPart = parts[2].split(separator: ".")
            guard let seconds = Int(secondsPart[0]) else { return nil }
            let deciseconds = secondsPart.count > 1 ? Int(secondsPart[1]) ?? 0 : 0
            return ((hours * 3600) + (minutes * 60) + seconds) * 1000 + deciseconds * 100

        case 2:
            let minutes: Int
            if parts[0].isEmpty {
                minutes = 0
            } else if let parsed = Int(parts[0]) {
                minutes = parsed
            } else {
                return nil
            }
            let secondsPart = parts[1].split(separator: ".")
            guard let seconds = Int(secondsPart[0]) else { return nil }
            let deciseconds = secondsPart.count > 1 ? Int(secondsPart[1]) ?? 0 : 0
            return (minutes * 60 + seconds) * 1000 + deciseconds * 100

        case 1:
            // A bare number, e.g. "47" typed for a sub-minute split.
            guard let seconds = Int(parts[0]) else { return nil }
            return seconds * 1000

        default:
            return nil
        }
    }
}
