//
//  UsernameRules.swift
//  Rowing Pals
//

import Foundation

/// Usernames (decision 85): unique, lower case, 3–20 of a–z 0–9 . _, not starting or ending with a
/// full stop — as the database's `profiles_username_valid` rule. Shown as @username; signing in
/// takes an email or a username in the same box.
nonisolated enum UsernameRules {
    static let minLength = 3
    static let maxLength = 20

    /// What's typed, as it's stored: trimmed, lower case, without a leading @.
    static func normalised(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("@") { value.removeFirst() }
        return value
    }

    /// Why a username can't be used, in plain words; nil when it's fine (it may still be taken).
    static func problem(with text: String) -> String? {
        let value = normalised(text)
        if value.count < minLength { return "A username needs at least \(minLength) characters." }
        if value.count > maxLength { return "A username can be at most \(maxLength) characters." }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._")
        if !value.allSatisfy(allowed.contains) { return "Use only letters, numbers, full stops and underscores." }
        if value.hasPrefix(".") || value.hasSuffix(".") { return "A username can’t start or end with a full stop." }
        return nil
    }

    /// A first suggestion from a name: "Piero Ciobanu" → "piero.ciobanu", accents dropped, other
    /// characters left out, cut to fit; "rower" when nothing's left.
    static func suggestion(from name: String) -> String {
        let plain = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_GB"))
            .lowercased()
        let words = plain.split { !$0.isLetter && !$0.isNumber }
            .map { String($0.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }) }
            .filter { !$0.isEmpty }
        var value = words.joined(separator: ".")
        if value.count > maxLength { value = String(value.prefix(maxLength)) }
        while value.hasSuffix(".") { value.removeLast() }
        return value.count >= minLength ? value : "rower"
    }

    /// Whether the sign-in box holds an email (anything with an @ after the first character).
    static func isEmail(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = value.firstIndex(of: "@") else { return false }
        return at != value.startIndex
    }
}
