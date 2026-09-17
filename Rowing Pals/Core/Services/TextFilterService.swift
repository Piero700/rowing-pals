//
//  TextFilterService.swift
//  Rowing Pals
//

import Foundation

/// Blocks a caption or comment from being written at all if it contains
/// obviously objectionable language — App Store Guideline 1.2's filtering
/// requirement, applied *before* anything becomes visible, not as a
/// post-hoc removal.
///
/// A fixed blocklist, not a moderation API: this app stays on-device and
/// zero-cost throughout (matches `OCRService`'s own on-device-only
/// approach) — a real decision, not a placeholder, see the note this task
/// left in conversation about weighing it against a paid third-party
/// service. It catches the clear, deliberate cases; it will never catch
/// everything a trained model would.
nonisolated enum TextFilterService {
    /// Deliberately short and unambiguous — slurs and explicit sexual
    /// terms, not borderline words a rower would plausibly type about a
    /// hard piece ("brutal", "killed it", etc. all pass fine).
    private static let blockedTerms: Set<String> = [
        "nigger", "nigga", "faggot", "retard", "kike", "chink", "spic", "tranny",
        "cunt", "whore", "slut"
    ]

    /// True if `text` should be blocked from posting.
    static func isBlocked(_ text: String) -> Bool {
        let words = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
        return words.contains { blockedTerms.contains($0) }
    }
}
