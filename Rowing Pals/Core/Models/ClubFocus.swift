//
//  ClubFocus.swift
//  Rowing Pals
//

import Foundation

/// What a club rows (`clubs.focus`) — the v2 prototype's "Club focus". "On-water rowing" was
/// removed with water logging (decision 54); docs/migrations/2026-10-14-erg-only.sql moves any
/// club that had it to "All rowing".
nonisolated enum ClubFocus: String, Codable, CaseIterable {
    case allRowing = "All rowing"
    case indoor = "Indoor rowing"
    case university = "University crew"
}
