//
//  ClubFocus.swift
//  Rowing Pals
//

import Foundation

/// What a club rows (`clubs.focus`) — the v2 prototype's "Club focus".
nonisolated enum ClubFocus: String, Codable, CaseIterable {
    case allRowing = "All rowing"
    case indoor = "Indoor rowing"
    case onWater = "On-water rowing"
    case university = "University crew"
}
