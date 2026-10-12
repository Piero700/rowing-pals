//
//  DurationEntry.swift
//  Rowing Pals
//

import Foundation

/// Typing a time as digits, with the colon put in for you — like a microwave or the erg's own
/// monitor: digits fill from the right, so "5" reads "0:05", "500" reads "5:00", "2000" reads
/// "20:00" and "6000" reads "60:00"; five or six digits add hours ("13000" → "1:30:00"). The
/// number pad has no colon to mistype, and the field always shows the time it will save.
enum DurationEntry {
    /// The most digits a time takes (hh:mm:ss).
    static let maxDigits = 6

    /// The digits of whatever was typed or pasted, without leading zeros, at most six.
    static func digits(from text: String) -> String {
        let digits = text.filter(\.isWholeNumber)
        let trimmed = digits.drop { $0 == "0" }
        return String(trimmed.prefix(maxDigits))
    }

    /// What the field shows: "" for no digits, otherwise m:ss or h:mm:ss.
    static func text(digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        let padded = String(repeating: "0", count: max(0, 3 - digits.count)) + digits
        let seconds = String(padded.suffix(2))
        let rest = padded.dropLast(2)
        guard rest.count > 2 else { return "\(Int(rest) ?? 0):\(seconds)" }
        let minutes = String(rest.suffix(2))
        let hours = rest.dropLast(2)
        return "\(Int(hours) ?? 0):\(minutes):\(seconds)"
    }

    /// The time in milliseconds; nil for no digits or seconds of 60 or more ("1:75").
    static func milliseconds(digits: String) -> Int? {
        guard !digits.isEmpty, let value = Int(digits) else { return nil }
        let seconds = value % 100
        guard seconds < 60 else { return nil }
        let minutesPart = value / 100
        if digits.count > 4 {
            let minutes = minutesPart % 100
            guard minutes < 60 else { return nil }
            return ((minutesPart / 100) * 3600 + minutes * 60 + seconds) * 1000
        }
        return (minutesPart * 60 + seconds) * 1000
    }

    /// The digits that show `ms` (whole seconds): 300,000 → "500" ("5:00").
    static func digits(milliseconds ms: Int) -> String {
        let total = ms / 1000
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        let text = hours > 0
            ? String(format: "%d%02d%02d", hours, minutes, seconds)
            : String(format: "%d%02d", minutes, seconds)
        return digits(from: text)
    }
}
