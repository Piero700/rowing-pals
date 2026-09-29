//
//  ClubRole.swift
//  Rowing Pals
//

import Foundation

/// A rower's role in their club (`profiles.club_role`, decision 25). Admins answer join requests,
/// invite and remove members; co-owners also change roles and edit the club; the owner can do
/// everything, including making co-owners, handing over and deleting the club.
nonisolated enum ClubRole: String, Codable, CaseIterable, Comparable {
    case member
    case admin
    case coOwner = "co_owner"
    case owner

    var label: String {
        switch self {
        case .member: "Member"
        case .admin: "Admin"
        case .coOwner: "Co-owner"
        case .owner: "Owner"
        }
    }

    var rank: Int {
        switch self {
        case .member: 0
        case .admin: 1
        case .coOwner: 2
        case .owner: 3
        }
    }

    /// Answer requests, invite, remove members below them.
    var canManageMembers: Bool { self >= .admin }
    /// Change roles and edit the club.
    var canEditClub: Bool { self >= .coOwner }

    /// Mirrors `remove_club_member` in docs/migrations/2026-09-30-clubs.sql.
    func canRemove(_ other: ClubRole) -> Bool { canManageMembers && other < self }

    /// The roles this rower may give `other` — mirrors `set_club_role`: co-owners and up change
    /// roles of those below them; only the owner makes or unmakes co-owners.
    func assignableRoles(for other: ClubRole) -> [ClubRole] {
        guard canEditClub, other < self else { return [] }
        return self == .owner ? [.member, .admin, .coOwner] : [.member, .admin]
    }

    static func < (lhs: ClubRole, rhs: ClubRole) -> Bool { lhs.rank < rhs.rank }
}
