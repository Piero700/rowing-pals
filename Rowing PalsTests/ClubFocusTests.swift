//
//  ClubFocusTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Erg only (decision 54): "On-water rowing" is no longer a club focus, and a club that still has
/// it stored (before the erg-only migration runs) loads as All rowing instead of failing.
struct ClubFocusTests {
    @Test func onWaterIsNotOffered() {
        #expect(ClubFocus.allCases.map(\.rawValue) == ["All rowing", "Indoor rowing", "University crew"])
    }

    @Test func aStoredOnWaterClubStillLoads() throws {
        let json = """
        {"id": "\(UUID())", "name": "River Club", "location": null, "crest_path": null,
         "description": null, "join_policy": "open", "focus": "On-water rowing",
         "created_at": "2026-10-01T10:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let club = try decoder.decode(Club.self, from: Data(json.utf8))
        #expect(club.focus == .allRowing)
    }
}
