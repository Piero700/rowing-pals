//
//  ReactionCatalog.swift
//  Rowing Pals
//

import Foundation

/// Every reaction the app knows, keyed by the text stored in `reactions.kind`. The 12 in
/// `picker` are the v3 "Choose a reaction" sheet, in its order
/// (docs/design/v3/rowing-pals-app.js). `legacy` kinds were offered before v3; they still
/// display on older posts but are no longer offered.
enum ReactionCatalog {
    struct Kind: Identifiable, Hashable {
        let key: String
        let emoji: String
        /// Spoken by VoiceOver.
        let name: String
        var id: String { key }
    }

    static let picker: [Kind] = [
        Kind(key: "fire", emoji: "🔥", name: "Fire"),
        Kind(key: "muscle", emoji: "💪", name: "Strong"),
        Kind(key: "clap", emoji: "👏", name: "Clap"),
        Kind(key: "party", emoji: "🎉", name: "Celebrate"),
        Kind(key: "boat", emoji: "🚣", name: "Rowing"),
        Kind(key: "heart", emoji: "❤️", name: "Love"),
        Kind(key: "praise", emoji: "🙌", name: "Praise"),
        Kind(key: "bolt", emoji: "⚡", name: "Fast"),
        Kind(key: "wow", emoji: "😮", name: "Wow"),
        Kind(key: "laugh", emoji: "😂", name: "Laugh"),
        Kind(key: "trophy", emoji: "🏆", name: "Trophy"),
        Kind(key: "blue_heart", emoji: "💙", name: "Blue heart")
    ]

    static let legacy: [Kind] = [
        Kind(key: "grimace", emoji: "😬", name: "Grimace"),
        Kind(key: "eyes", emoji: "👀", name: "Eyes")
    ]

    private static let byKey: [String: Kind] = Dictionary(
        uniqueKeysWithValues: (picker + legacy).map { ($0.key, $0) }
    )

    static func kind(for key: String) -> Kind? { byKey[key] }

    /// The emoji for a stored kind; an unknown kind shows a neutral mark rather than nothing.
    static func emoji(for key: String) -> String { byKey[key]?.emoji ?? "•" }

    /// Display order: picker order first, then legacy, then anything unknown alphabetically.
    static func sortIndex(for key: String) -> Int {
        if let index = picker.firstIndex(where: { $0.key == key }) { return index }
        if let index = legacy.firstIndex(where: { $0.key == key }) { return picker.count + index }
        return picker.count + legacy.count
    }
}
