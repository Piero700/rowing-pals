//
//  WrappedPeriod.swift
//  Rowing Pals
//

import Foundation

/// What a Season Wrapped covers (decision 92): one of the club's terms, or days the rower chooses.
nonisolated struct WrappedPeriod: Identifiable, Equatable, Hashable, Sendable {
    /// The club term's id; nil for chosen days.
    let termId: UUID?
    /// "Michaelmas 2026", "Your dates".
    let title: String
    /// "yyyy-MM-dd", both counted.
    let startsOn: String
    let endsOn: String

    var id: String { termId?.uuidString ?? "custom-\(startsOn)-\(endsOn)" }

    var isCustom: Bool { termId == nil }
}
