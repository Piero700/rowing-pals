//
//  AttendanceMark.swift
//  Rowing Pals
//

import Foundation

/// The coach's current mark for one rower at one practice, with who set it and when. Mirrors
/// `attendance_marks`.
nonisolated struct AttendanceMark: Decodable, Equatable, Hashable {
    let practiceId: UUID
    let userId: UUID
    let mark: RegisterMark
    let setBy: UUID?
    let setAt: Date

    enum CodingKeys: String, CodingKey {
        case mark
        case practiceId = "practice_id"
        case userId = "user_id"
        case setBy = "set_by"
        case setAt = "set_at"
    }
}
