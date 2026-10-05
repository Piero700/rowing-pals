//
//  RankingsGroupTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Rankings open on the viewer's own group (decision 37): the filter wording, the group a
/// rower opens on, and the "Best in your group" comparison.
struct RankingsGroupTests {
    private let twoK = StandardTest.all.first { $0.key == "2k" }!
    private let me = UUID()
    private let tom = UUID()
    private let ollie = UUID()

    @Test func filterWording() {
        #expect(RankingsFilters(gender: .male, level: .senior).captionText == "Senior men · My club")
        #expect(RankingsFilters(gender: .female, level: nil).groupLabel == "Women")
        #expect(RankingsFilters(gender: nil, level: .novice, scope: .following).captionText == "Novice rowers · Following")
        #expect(RankingsFilters.initial.groupLabel == "All rowers")
    }

    @Test func opensOnYourOwnGroup() {
        let group = ViewerGroup(gender: .male, level: .senior, clubName: "UEA Boat Club")
        #expect(group.filters == RankingsFilters(gender: .male, level: .senior, scope: .myClub))
        #expect(group.sentence == "Opens on your own group: senior men in UEA Boat Club.")
        // No gender on file: everyone in the club, not a level-only slice.
        #expect(ViewerGroup(gender: nil, level: .novice, clubName: nil).filters == .initial)
    }

    @Test func someoneElseLeadsByAGap() {
        let best = GroupBest.make(test: twoK, results: [
            .init(userId: tom, name: "Tom", timeMs: 372_400),
            .init(userId: me, name: "Me", timeMs: 379_400),
            .init(userId: me, name: "Me", timeMs: 378_900),
        ], viewerId: me)
        #expect(best.leader?.userId == tom)
        #expect(!best.leaderIsViewer)
        #expect(best.standing == "You’re 6.5s behind")
    }

    @Test func youLeadIncludingATie() {
        let best = GroupBest.make(test: twoK, results: [
            .init(userId: ollie, name: "Ollie", timeMs: 400_000),
            .init(userId: me, name: "Me", timeMs: 400_000),
        ], viewerId: me)
        #expect(best.leaderIsViewer)
        #expect(best.standing == "Fastest in your group")
    }

    @Test func noResultYet() {
        let mine = GroupBest.make(test: twoK, results: [.init(userId: tom, name: "Tom", timeMs: 372_400)], viewerId: me)
        #expect(mine.standing == "No result from you yet")
        let nobody = GroupBest.make(test: twoK, results: [], viewerId: me)
        #expect(nobody.leader == nil)
        #expect(nobody.standing == "No results in your group yet")
    }

    @Test func gapLabels() {
        #expect(GroupBest.gapLabel(6_500) == "6.5s")
        #expect(GroupBest.gapLabel(59_900) == "59.9s")
        #expect(GroupBest.gapLabel(64_200) == "1:04.2")
    }
}
