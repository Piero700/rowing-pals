//
//  AttendanceMarkLogEntry.swift
//  Rowing Pals
//

import Foundation

/// One mark ever set, so a change stays visible ("You changed Present → Late at 17:45"). Mirrors
/// `attendance_mark_log`.
nonisolated struct AttendanceMarkLogEntry: Decodable, Equatable, Hashable {
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
