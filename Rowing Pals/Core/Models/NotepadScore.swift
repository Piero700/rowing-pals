//
//  NotepadScore.swift
//  Rowing Pals
//

import Foundation

/// A score a coach put on the notepad for one rower's rep (decision 96): a split, with what was
/// typed to get it (the time or the metres) and the rate, or sat out. Mirrors
/// `coach_notepad_scores`. Coach-only: nothing outside the notepad ever reads it.
nonisolated struct NotepadScore: Decodable, Equatable {
    enum Source: String, Decodable {
        case typed
        /// Read off the rower's monitor (phase NP2).
        case scanned
    }

    let workoutId: UUID
    let userId: UUID
    /// The rep, counting every rep of every piece from 0.
    let pieceIndex: Int
    /// Nil only when sat out.
    let splitMs: Int?
    let timeMs: Int?
    let distanceM: Int?
    let rate: Int?
    let satOut: Bool
    let source: Source
    /// A test's 500m splits, when they were scanned off the monitor (NP3).
    let splits500Ms: [Int]?

    enum CodingKeys: String, CodingKey {
        case rate, source
        case workoutId = "workout_id"
        case userId = "user_id"
        case pieceIndex = "piece_index"
        case splitMs = "split_ms"
        case timeMs = "time_ms"
        case distanceM = "distance_m"
        case satOut = "sat_out"
        case splits500Ms = "splits_500_ms"
    }

    init(workoutId: UUID, userId: UUID, pieceIndex: Int, splitMs: Int?, timeMs: Int? = nil,
         distanceM: Int? = nil, rate: Int? = nil, satOut: Bool = false, source: Source = .typed,
         splits500Ms: [Int]? = nil) {
        self.workoutId = workoutId
        self.userId = userId
        self.pieceIndex = pieceIndex
        self.splitMs = splitMs
        self.timeMs = timeMs
        self.distanceM = distanceM
        self.rate = rate
        self.satOut = satOut
        self.source = source
        self.splits500Ms = splits500Ms
    }
}
