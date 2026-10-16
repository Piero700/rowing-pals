//
//  RegisterMark.swift
//  Rowing Pals
//

/// The coach's mark on the register (decision 39). It always counts over the rower's own answer.
/// Present and Late count as attended; Excused is left out of the total.
nonisolated enum RegisterMark: String, Codable, CaseIterable {
    case present, late, absent, excused

    var label: String {
        switch self {
        case .present: "Present"
        case .late: "Late"
        case .absent: "Absent"
        case .excused: "Excused"
        }
    }

    /// One letter, for the attendance strip on a rower's page.
    var initial: String { String(label.prefix(1)) }

    var counted: Bool { self != .excused }
    var attended: Bool { self == .present || self == .late }
}
