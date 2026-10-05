//
//  WorkoutPiece.swift
//  Rowing Pals
//

import Foundation

/// One piece of a coach's set workout (CoachWorkoutNew, decision 39): a distance or a time,
/// rowed `reps` times, with optional rest, target rate and target split. Stored in
/// `coach_workouts.pieces` as JSON with these snake_case keys.
nonisolated struct WorkoutPiece: Codable, Equatable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case distance
        case time
    }

    var id = UUID()
    var kind: Kind
    /// Metres for a distance piece, milliseconds for a time piece.
    var value: Int
    var reps: Int
    var restMs: Int?
    var rateMin: Int?
    var rateMax: Int?
    /// One split for every rower; nil means each rower's own target from the Pace Engine
    /// (decision 51).
    var splitMs: Int?

    enum CodingKeys: String, CodingKey {
        case kind, value, reps
        case restMs = "rest_ms"
        case rateMin = "rate_min"
        case rateMax = "rate_max"
        case splitMs = "split_ms"
    }

    init(kind: Kind, value: Int, reps: Int = 1, restMs: Int? = nil, rateMin: Int? = nil,
         rateMax: Int? = nil, splitMs: Int? = nil) {
        self.kind = kind
        self.value = value
        self.reps = reps
        self.restMs = restMs
        self.rateMin = rateMin
        self.rateMax = rateMax
        self.splitMs = splitMs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        value = try c.decode(Int.self, forKey: .value)
        reps = max(1, try c.decodeIfPresent(Int.self, forKey: .reps) ?? 1)
        restMs = try c.decodeIfPresent(Int.self, forKey: .restMs)
        rateMin = try c.decodeIfPresent(Int.self, forKey: .rateMin)
        rateMax = try c.decodeIfPresent(Int.self, forKey: .rateMax)
        splitMs = try c.decodeIfPresent(Int.self, forKey: .splitMs)
    }

    /// The `id` is the app's own handle for editing; it isn't stored.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encode(value, forKey: .value)
        try c.encode(reps, forKey: .reps)
        try c.encodeIfPresent(restMs, forKey: .restMs)
        try c.encodeIfPresent(rateMin, forKey: .rateMin)
        try c.encodeIfPresent(rateMax, forKey: .rateMax)
        try c.encodeIfPresent(splitMs, forKey: .splitMs)
    }
}
