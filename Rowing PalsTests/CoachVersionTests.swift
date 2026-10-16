//
//  CoachVersionTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The coach version (decision 67): which version opens, and a rower's side.
struct CoachVersionTests {
    @Test func someoneWhoIsNotACoachAlwaysRows() {
        #expect(AppMode.resolved(isCoach: false, isRower: true, preferred: .coaching) == .rowing)
        // A coach-only account its club hasn't made a coach yet keeps the rower version.
        #expect(AppMode.resolved(isCoach: false, isRower: false, preferred: .rowing) == .rowing)
    }

    @Test func aCoachWhoDoesNotRowAlwaysCoaches() {
        #expect(AppMode.resolved(isCoach: true, isRower: false, preferred: .rowing) == .coaching)
        #expect(AppMode.resolved(isCoach: true, isRower: false, preferred: .coaching) == .coaching)
    }

    @Test func aCoachWhoRowsGetsTheVersionUsedLast() {
        #expect(AppMode.resolved(isCoach: true, isRower: true, preferred: .rowing) == .rowing)
        #expect(AppMode.resolved(isCoach: true, isRower: true, preferred: .coaching) == .coaching)
    }

    @Test func theSideLoadsFromTheProfile() throws {
        let profile = try decodeProfile(side: "\"bow\"")
        #expect(profile.side == .bow)
        #expect(RowingSide.allCases.map(\.label) == ["Stroke side", "Bow side", "Both"])
    }

    @Test func aProfileWithNoSideStillLoads() throws {
        // No side chosen, or the coach-version migration hasn't run yet.
        #expect(try decodeProfile(side: "null").side == nil)
        #expect(try decodeProfile(side: nil).side == nil)
    }

    private func decodeProfile(side: String?) throws -> Profile {
        let sideField = side.map { "\"side\": \($0)," } ?? ""
        let json = """
        {"id": "\(UUID())", "display_name": "Piero", "category": "senior", "gender": "M",
         "weekly_target_sessions": 5, "weekly_target_m": 60000, \(sideField)
         "created_at": "2026-10-01T10:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: Data(json.utf8))
    }
}
