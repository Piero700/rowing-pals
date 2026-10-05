//
//  CoachFlag.swift
//  Rowing Pals
//

import Foundation
import PaceEngine

/// Something a coach should look at for one rower (decision 39): the Pace Engine's
/// `elevated_recent_effort` and `tier_disagreement`, and no session in 10 or more days.
nonisolated enum CoachFlag: Equatable, Hashable {
    /// No session for `days` days (10 or more); nil days when nothing was logged in the window
    /// read, which reaches back `CoachingRules.historyDays`.
    case noRecentSession(days: Int?)
    /// The engine's `elevated_recent_effort`. `percentAbove` is the last 7 days' average effort
    /// against the 4-week average, when both have ratings.
    case elevatedEffort(percentAbove: Int?)
    /// The engine's `tier_disagreement`. `logged` and `likely` name the zones when one zone
    /// clearly disagrees with the rest; otherwise only the spread is known.
    case likelyMistagged(logged: Tier.Name?, likely: Tier.Name?, spreadSeconds: Double)

    /// The short chip on a rower card.
    var chipText: String {
        switch self {
        case .noRecentSession(let days):
            if let days { return "No session in \(days) days" }
            return "No session in \(CoachingRules.historyDays)+ days"
        case .elevatedEffort:
            return "Elevated recent effort"
        case .likelyMistagged(let logged, let likely, _):
            if let logged, let likely { return "Likely mis-tagged: \(likely.rawValue) logged as \(logged.rawValue)" }
            return "Likely mis-tagged sessions"
        }
    }

    /// The longer line under the title on one rower's page.
    var detailText: String {
        switch self {
        case .noRecentSession(let days):
            if let days { return "Their last session was \(days) days ago." }
            return "Nothing logged in the last \(CoachingRules.historyDays) days."
        case .elevatedEffort(let percent):
            if let percent { return "Effort over the last 7 days is \(percent)% above their 4-week average." }
            return "Recent sessions felt harder than their zones suggest."
        case .likelyMistagged(let logged, let likely, let spread):
            let gap = String(format: "%.1f", spread)
            if let logged, let likely {
                return "Their \(logged.rawValue) sessions were rowed at about \(likely.rawValue) pace; zones disagree by \(gap)s /500m."
            }
            return "Their zones disagree by \(gap)s /500m, so some sessions are probably tagged wrongly."
        }
    }

    /// Red chips for a problem with the rower; a neutral chip for a data problem.
    var isWarning: Bool {
        switch self {
        case .noRecentSession, .elevatedEffort: true
        case .likelyMistagged: false
        }
    }

    var title: String {
        switch self {
        case .noRecentSession: "No recent session"
        case .elevatedEffort: "Elevated recent effort"
        case .likelyMistagged: "Likely mis-tagged sessions"
        }
    }
}
