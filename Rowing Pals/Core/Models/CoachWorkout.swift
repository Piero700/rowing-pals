//
//  CoachWorkout.swift
//  Rowing Pals
//

import Foundation

/// A workout a coach has set (decisions 34, 39): a day, an optional start time, a description,
/// a target zone, optional pieces, an optional test (test day) and who it's for. Mirrors
/// `coach_workouts` with its `coach_workout_targets`.
nonisolated struct CoachWorkout: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let clubId: UUID
    let createdBy: UUID?
    let title: String
    /// The workout's day, "yyyy-MM-dd" (a calendar day, not an instant).
    let workoutDate: String
    /// "HH:mm:ss", or nil for no set time.
    let startTime: String?
    let description: String?
    /// "UT2" … "AN", or nil.
    let zone: String?
    /// A standard test's key ("2k") or a club test's ("club:<id>") on a test day.
    let testKey: String?
    let pieces: [WorkoutPiece]
    let audience: WorkoutAudience
    /// The squads or rowers chosen, when the audience isn't the whole club. Empty when not read.
    let squadIds: [UUID]
    let rowerIds: [UUID]

    struct Target: Decodable {
        let squadId: UUID?
        let userId: UUID?
        enum CodingKeys: String, CodingKey {
            case squadId = "squad_id"
            case userId = "user_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, zone, pieces, audience
        case clubId = "club_id"
        case createdBy = "created_by"
        case workoutDate = "workout_date"
        case startTime = "start_time"
        case testKey = "test_key"
        case targets = "coach_workout_targets"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clubId = try c.decode(UUID.self, forKey: .clubId)
        createdBy = try c.decodeIfPresent(UUID.self, forKey: .createdBy)
        title = try c.decode(String.self, forKey: .title)
        workoutDate = try c.decode(String.self, forKey: .workoutDate)
        startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        zone = try c.decodeIfPresent(String.self, forKey: .zone)
        testKey = try c.decodeIfPresent(String.self, forKey: .testKey)
        pieces = try c.decodeIfPresent([WorkoutPiece].self, forKey: .pieces) ?? []
        audience = try c.decodeIfPresent(WorkoutAudience.self, forKey: .audience) ?? .club
        let targets = try c.decodeIfPresent([Target].self, forKey: .targets) ?? []
        squadIds = targets.compactMap(\.squadId)
        rowerIds = targets.compactMap(\.userId)
    }

    init(id: UUID, clubId: UUID, createdBy: UUID?, title: String, workoutDate: String, startTime: String?,
         description: String?, zone: String?, testKey: String?, pieces: [WorkoutPiece],
         audience: WorkoutAudience, squadIds: [UUID] = [], rowerIds: [UUID] = []) {
        self.id = id
        self.clubId = clubId
        self.createdBy = createdBy
        self.title = title
        self.workoutDate = workoutDate
        self.startTime = startTime
        self.description = description
        self.zone = zone
        self.testKey = testKey
        self.pieces = pieces
        self.audience = audience
        self.squadIds = squadIds
        self.rowerIds = rowerIds
    }

    var isTestDay: Bool { testKey != nil }
}
