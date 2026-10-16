//
//  PracticeResponse.swift
//  Rowing Pals
//

import Foundation

/// One rower's own answer to one practice: Available or Can't (with a reason only coaches see),
/// and when they checked in on the day. Mirrors `attendance_responses`.
nonisolated struct PracticeResponse: Decodable, Equatable, Hashable {
    let practiceId: UUID
    let userId: UUID
    let answer: PracticeAnswer?
    let reason: String?
    let checkedInAt: Date?

    enum CodingKeys: String, CodingKey {
        case answer, reason
        case practiceId = "practice_id"
        case userId = "user_id"
        case checkedInAt = "checked_in_at"
    }
}
