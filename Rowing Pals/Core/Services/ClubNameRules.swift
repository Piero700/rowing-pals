//
//  ClubNameRules.swift
//  Rowing Pals
//

import Foundation

/// Club names (decision 98): anyone can start a club and call it anything, but no two clubs share
/// a name. Two names are the same when they match ignoring capitals and extra spaces — "Tyne RC",
/// "tyne rc" and " Tyne  RC " are one name. The database enforces it (`club_name_key`, the unique
/// index in docs/migrations/2026-11-05-clubs-open-and-verified.sql); these rules mirror it so the
/// app can say so while the name is typed.
nonisolated enum ClubNameRules {
    static let maxLength = 60

    /// The name as it's stored: trimmed, every run of spaces made one.
    static func tidied(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The form two names are compared in, as `club_name_key` in the database.
    static func key(_ text: String) -> String {
        tidied(text).lowercased()
    }

    /// Whether two names count as the same name.
    static func isSameName(_ first: String, _ second: String) -> Bool {
        key(first) == key(second)
    }

    /// Why a name can't be used, in plain words; nil when it's fine (it may still be taken).
    static func problem(with text: String) -> String? {
        let name = tidied(text)
        if name.isEmpty { return "Give your club a name." }
        if name.count > maxLength { return "Club names can be up to \(maxLength) characters." }
        return nil
    }

    /// What to say when another club already has the name.
    static func takenMessage(for text: String) -> String {
        "There’s already a club called \(tidied(text)). Club names have to be different (capitals don’t count), so choose another name."
    }
}
