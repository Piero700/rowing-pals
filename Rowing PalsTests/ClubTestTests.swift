//
//  ClubTestTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Club tests (decision 28): the names the app shows while an admin types must be the ones the
/// database gives (`club_test_label`), the checks must match `create_club_test`, and a club test
/// must behave like a standard one once posted.
struct ClubTestTests {
    private func clubTest(distanceM: Int? = nil, durationMs: Int? = nil, label: String) -> ClubTest {
        ClubTest(id: UUID(), clubId: UUID(), label: label, distanceM: distanceM, durationMs: durationMs)
    }

    @Test func namesFollowTheStandardTilesStyle() {
        #expect(ClubTest.label(distanceM: 750, minutes: nil) == "750m")
        #expect(ClubTest.label(distanceM: 3000, minutes: nil) == "3k")
        #expect(ClubTest.label(distanceM: 1500, minutes: nil) == "1500m")
        #expect(ClubTest.label(distanceM: nil, minutes: 20) == "20min")
        #expect(ClubTest.label(distanceM: nil, minutes: nil) == nil)
    }

    @Test func standardTestsCannotBeAddedAgain() {
        #expect(ClubTest.problem(distanceM: 2000, minutes: nil, existing: []) == "That's already a standard test.")
        #expect(ClubTest.problem(distanceM: nil, minutes: 30, existing: []) == "That's already a standard test.")
        #expect(ClubTest.problem(distanceM: 3000, minutes: nil, existing: []) == nil)
        #expect(ClubTest.problem(distanceM: nil, minutes: 20, existing: []) == nil)
    }

    @Test func aClubCannotHaveTheSameTestTwice() {
        let existing = [clubTest(distanceM: 750, label: "750m")]
        #expect(ClubTest.problem(distanceM: 750, minutes: nil, existing: existing) == "Your club already has a 750m test.")
        #expect(ClubTest.problem(distanceM: 1500, minutes: nil, existing: existing) == nil)
    }

    @Test func limitsMatchTheDatabase() {
        #expect(ClubTest.problem(distanceM: 99, minutes: nil, existing: []) != nil)
        #expect(ClubTest.problem(distanceM: 100_001, minutes: nil, existing: []) != nil)
        #expect(ClubTest.problem(distanceM: nil, minutes: 0, existing: []) != nil)
        #expect(ClubTest.problem(distanceM: nil, minutes: 121, existing: []) != nil)
        #expect(ClubTest.problem(distanceM: nil, minutes: nil, existing: []) == "Enter a distance or a time.")
    }

    @Test func keyIsTheLowerCaseIdTheDatabaseWrites() {
        let test = clubTest(distanceM: 750, label: "750m")
        #expect(test.key == "club:" + test.id.uuidString.lowercased())
        #expect(test.asTest.key == test.key)
    }

    @Test func aClubTestIsCheckedLikeAStandardOne() {
        let distance = clubTest(distanceM: 750, label: "750m").asTest
        #expect(!distance.isDurationBased)
        #expect(distance.accepts(distanceM: 750, timeMs: 150_000))
        #expect(!distance.accepts(distanceM: 760, timeMs: 150_000))
        #expect(SessionKind.test(distance).problem(distanceM: 700, timeMs: 150_000) == "A 750m test must be exactly 750m.")

        let timed = clubTest(durationMs: 20 * 60_000, label: "20min").asTest
        #expect(timed.isDurationBased)
        #expect(timed.accepts(distanceM: 5000, timeMs: 20 * 60_000 + 1500))
        #expect(!timed.accepts(distanceM: 5000, timeMs: 19 * 60_000))
    }

    @Test func distancesComeFirstThenTimesShortestFirst() {
        let tests = [
            clubTest(durationMs: 20 * 60_000, label: "20min"),
            clubTest(distanceM: 3000, label: "3k"),
            clubTest(durationMs: 12 * 60_000, label: "12min"),
            clubTest(distanceM: 750, label: "750m")
        ]
        #expect(ClubTest.sorted(tests).map(\.label) == ["750m", "3k", "12min", "20min"])
    }
}
