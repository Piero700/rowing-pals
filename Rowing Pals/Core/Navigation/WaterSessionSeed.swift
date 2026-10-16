//
//  WaterSessionSeed.swift
//  Rowing Pals
//

import Foundation

/// Where a new water session starts from (decision 67): a day on the Calendar, a practice's
/// "Plan boats for this session", a race's "Crew boats for this race", or + on its own.
nonisolated struct WaterSessionSeed: Hashable, Sendable {
    var day: Date?
    var practiceId: UUID?
    var eventId: UUID?

    init(day: Date? = nil, practiceId: UUID? = nil, eventId: UUID? = nil) {
        self.day = day
        self.practiceId = practiceId
        self.eventId = eventId
    }
}
