//
//  ClubRoleTests.swift
//  Rowing PalsTests
//

import Testing
@testable import Rowing_Pals

/// The app's copy of the club permission rules (decision 25). The server enforces the same
/// rules in docs/migrations/2026-09-30-clubs.sql; these keep the buttons the app shows honest.
struct ClubRoleTests {
    @Test func rolesRankInOrder() {
        #expect(ClubRole.member < .admin && ClubRole.admin < .coOwner && ClubRole.coOwner < .owner)
    }

    @Test func adminsManageMembersButNotRoles() {
        #expect(ClubRole.admin.canManageMembers)
        #expect(!ClubRole.admin.canEditClub)
        #expect(ClubRole.admin.assignableRoles(for: .member).isEmpty)
        #expect(!ClubRole.member.canManageMembers)
    }

    @Test func coOwnersChangeRolesBelowThemButNeverMakeCoOwners() {
        #expect(ClubRole.coOwner.assignableRoles(for: .member) == [.member, .admin])
        #expect(ClubRole.coOwner.assignableRoles(for: .admin) == [.member, .admin])
        #expect(ClubRole.coOwner.assignableRoles(for: .coOwner).isEmpty)
    }

    @Test func onlyTheOwnerMakesCoOwners() {
        #expect(ClubRole.owner.assignableRoles(for: .member) == [.member, .admin, .coOwner])
        #expect(ClubRole.owner.assignableRoles(for: .coOwner) == [.member, .admin, .coOwner])
    }

    @Test func removalOnlyBelowYou() {
        #expect(ClubRole.admin.canRemove(.member))
        #expect(!ClubRole.admin.canRemove(.admin))
        #expect(ClubRole.coOwner.canRemove(.admin))
        #expect(!ClubRole.coOwner.canRemove(.coOwner))
        #expect(ClubRole.owner.canRemove(.coOwner))
        #expect(!ClubRole.member.canRemove(.member))
    }

    @Test func databaseValuesDecode() throws {
        #expect(ClubRole(rawValue: "co_owner") == .coOwner)
        #expect(ClubJoinPolicy(rawValue: "approval")?.tag == "Approval required")
        #expect(ClubFocus(rawValue: "University crew") == .university)
    }
}
