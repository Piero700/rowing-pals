//
//  GroupBest.swift
//  Rowing Pals
//

import Foundation

/// One "Best in your group" card on Test results (decision 37): the fastest result for a test
/// among the viewer's own group — their gender and level, in their club — and how the viewer
/// stands against it. Results use the gender and level recorded with each result, as the test
/// boards do.
struct GroupBest: Identifiable, Equatable {
    struct Result: Equatable {
        let userId: UUID
        let name: String
        let timeMs: Int
    }

    let test: StandardTest
    /// Nil when nobody in the group has a result for this test yet.
    let leader: Result?
    let leaderIsViewer: Bool
    /// "You're 6.5s behind", "Fastest in your group", or "No result from you yet".
    let standing: String

    var id: String { test.key }

    /// Each rower's best, then the fastest of those; a tie goes to the viewer.
    static func make(test: StandardTest, results: [Result], viewerId: UUID) -> GroupBest {
        var best: [UUID: Result] = [:]
        for result in results where result.timeMs < (best[result.userId]?.timeMs ?? .max) {
            best[result.userId] = result
        }
        let own = best[viewerId]
        guard let fastest = best.values.min(by: { $0.timeMs < $1.timeMs }) else {
            return GroupBest(test: test, leader: nil, leaderIsViewer: false, standing: "No results in your group yet")
        }
        if let own, own.timeMs <= fastest.timeMs {
            return GroupBest(test: test, leader: own, leaderIsViewer: true, standing: "Fastest in your group")
        }
        guard let own else {
            return GroupBest(test: test, leader: fastest, leaderIsViewer: false, standing: "No result from you yet")
        }
        let gap = own.timeMs - fastest.timeMs
        return GroupBest(test: test, leader: fastest, leaderIsViewer: false, standing: "You’re \(gapLabel(gap)) behind")
    }

    /// Tenths of a second under a minute ("6.5s"), else minutes and seconds ("1:04.2").
    static func gapLabel(_ ms: Int) -> String {
        let tenths = ms / 100
        if tenths < 600 {
            return "\(tenths / 10).\(tenths % 10)s"
        }
        return ms.formattedDurationMs
    }
}
