//
//  ClubJoinPolicy.swift
//  Rowing Pals
//

import Foundation

/// Who can join a club (`clubs.join_policy`) — the v2 prototype's "Who can join?".
nonisolated enum ClubJoinPolicy: String, Codable, CaseIterable {
    case open
    case approval
    case invite

    /// The create/edit form's choice.
    var choiceLabel: String {
        switch self {
        case .open: "Anyone can join"
        case .approval: "Request approval"
        case .invite: "Invitation only"
        }
    }

    /// The tag on a club row ("48 members · Norwich · Open membership").
    var tag: String {
        switch self {
        case .open: "Open membership"
        case .approval: "Approval required"
        case .invite: "Invitation only"
        }
    }
}
