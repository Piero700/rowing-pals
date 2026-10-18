//
//  SeasonWrapped.swift
//  Rowing Pals
//

import Foundation

/// One rower's season (decision 92; what `season_wrapped(p_from, p_to)` returns): totals and streaks,
/// PBs and the best 2k, their place in the club and who they trained with, and their training mix.
nonisolated struct SeasonWrapped: Decodable, Equatable, Sendable {
    /// A week or a month and its metres.
    struct Peak: Decodable, Equatable, Sendable {
        /// "yyyy-MM-dd", the week's Monday or the month's first.
        let start: String
        let metres: Int
    }

    struct PB: Decodable, Equatable, Sendable {
        /// The test: "2k", "500m", "30min".
        let key: String
        let distanceM: Int
        let timeMs: Int
        let day: String
        enum CodingKeys: String, CodingKey {
            case key, day
            case distanceM = "distance_m"
            case timeMs = "time_ms"
        }
    }

    struct ClubPlace: Decodable, Equatable, Sendable {
        let place: Int
        let of: Int
        /// "senior men", "rowers in your club".
        let group: String
    }

    struct Mate: Decodable, Equatable, Sendable, Identifiable {
        let userId: UUID
        let name: String
        let sessions: Int
        var id: UUID { userId }
        enum CodingKeys: String, CodingKey {
            case name, sessions
            case userId = "user_id"
        }
    }

    struct ZoneTime: Decodable, Equatable, Sendable, Identifiable {
        let zone: String
        let timeMs: Int
        var id: String { zone }
        enum CodingKeys: String, CodingKey {
            case zone
            case timeMs = "time_ms"
        }
    }

    struct TimeOfDay: Decodable, Equatable, Sendable {
        let morning: Int
        let afternoon: Int
        let evening: Int
    }

    let metres: Int
    let sessions: Int
    let days: Int
    let timeMs: Int
    let longestStreak: Int
    let biggestWeek: Peak?
    let busiestMonth: Peak?
    let pbs: [PB]
    let best2kMs: Int?
    let best2kBeforeMs: Int?
    let clubPlace: ClubPlace?
    let trainedWith: [Mate]
    let challengesDone: [String]
    let zones: [ZoneTime]
    let timeOfDay: TimeOfDay?

    enum CodingKeys: String, CodingKey {
        case metres, sessions, days, pbs, zones
        case timeMs = "time_ms"
        case longestStreak = "longest_streak"
        case biggestWeek = "biggest_week"
        case busiestMonth = "busiest_month"
        case best2kMs = "best_2k_ms"
        case best2kBeforeMs = "best_2k_before_ms"
        case clubPlace = "club_place"
        case trainedWith = "trained_with"
        case challengesDone = "challenges_done"
        case timeOfDay = "time_of_day"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        metres = try c.decodeIfPresent(Int.self, forKey: .metres) ?? 0
        sessions = try c.decodeIfPresent(Int.self, forKey: .sessions) ?? 0
        days = try c.decodeIfPresent(Int.self, forKey: .days) ?? 0
        timeMs = try c.decodeIfPresent(Int.self, forKey: .timeMs) ?? 0
        longestStreak = try c.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        biggestWeek = try c.decodeIfPresent(Peak.self, forKey: .biggestWeek)
        busiestMonth = try c.decodeIfPresent(Peak.self, forKey: .busiestMonth)
        pbs = try c.decodeIfPresent([PB].self, forKey: .pbs) ?? []
        best2kMs = try c.decodeIfPresent(Int.self, forKey: .best2kMs)
        best2kBeforeMs = try c.decodeIfPresent(Int.self, forKey: .best2kBeforeMs)
        clubPlace = try c.decodeIfPresent(ClubPlace.self, forKey: .clubPlace)
        trainedWith = try c.decodeIfPresent([Mate].self, forKey: .trainedWith) ?? []
        challengesDone = try c.decodeIfPresent([String].self, forKey: .challengesDone) ?? []
        zones = try c.decodeIfPresent([ZoneTime].self, forKey: .zones) ?? []
        timeOfDay = try c.decodeIfPresent(TimeOfDay.self, forKey: .timeOfDay)
    }

    /// Nothing rowed in the season: a quiet page instead of the story.
    var isEmpty: Bool { sessions == 0 && metres == 0 }

    /// How much faster the season's best 2k is than the best before it; nil without both, or if it's slower.
    var twoKImprovementMs: Int? {
        guard let best = best2kMs, let before = best2kBeforeMs, before > best else { return nil }
        return before - best
    }

    /// When they row most: "mornings", "afternoons", "evenings"; nil with nothing logged.
    var favouriteTime: String? {
        guard let times = timeOfDay else { return nil }
        let ranked = [("mornings", times.morning), ("afternoons", times.afternoon), ("evenings", times.evening)]
            .sorted { $0.1 > $1.1 }
        return (ranked.first?.1 ?? 0) > 0 ? ranked.first?.0 : nil
    }
}
