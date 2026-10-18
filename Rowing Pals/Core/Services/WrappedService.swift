//
//  WrappedService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Season Wrapped (decision 92; docs/migrations/2026-10-18-season-wrapped.sql): the signed-in rower's
/// season worked out by the database, and the club's terms to choose from.
enum WrappedService {
    /// The rower's season between the period's days.
    static func wrapped(for period: WrappedPeriod) async throws -> SeasonWrapped {
        struct Params: Encodable {
            let p_from: String
            let p_to: String
        }
        return try await SupabaseService.shared
            .rpc("season_wrapped", params: Params(p_from: period.startsOn, p_to: period.endsOn)).execute().value
    }

    /// The club's terms that have begun, latest first; none without a club or terms.
    static func periods(today: Date = Date()) async -> [WrappedPeriod] {
        let terms = (try? await CalendarService.terms()) ?? []
        return WrappedRules.periods(from: terms, today: ChallengeRules.day(today, calendar: .current))
    }

    /// The term that's just ended, if any: its Wrapped goes on the Feed.
    static func readyTerm(today: Date = Date()) async -> WrappedPeriod? {
        let terms = (try? await CalendarService.terms()) ?? []
        return WrappedRules.readyTerm(terms, today: today, calendar: .current)
    }
}
