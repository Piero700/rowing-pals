//
//  ErgEvent.swift
//  Rowing Pals
//

import Foundation

/// An erg event (decision 91; mirrors `erg_events`): a set piece — a distance or a time — rowed in a
/// window ("Club 2k day, Sat 09:00–12:00"). A post during it, or up to six hours after, can count.
nonisolated struct ErgEvent: Decodable, Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let clubId: UUID
    let title: String
    let distanceM: Int?
    let durationMs: Int?
    let startsAt: Date
    let endsAt: Date

    /// How long after the window a piece can still be posted for it.
    static let postingGrace: TimeInterval = 6 * 3600

    enum CodingKeys: String, CodingKey {
        case id, title
        case clubId = "club_id"
        case distanceM = "distance_m"
        case durationMs = "duration_ms"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
    }

    /// "2k", "750m", "30min", "1min 30s" — as club tests are named.
    var pieceLabel: String { Self.pieceLabel(distanceM: distanceM, durationMs: durationMs) }

    static func pieceLabel(distanceM: Int?, durationMs: Int?) -> String {
        if let distanceM {
            return distanceM % 1000 == 0 ? "\(distanceM / 1000)k" : "\(distanceM)m"
        }
        let seconds = (durationMs ?? 0) / 1000
        if seconds % 60 == 0 { return "\(seconds / 60)min" }
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)min \(seconds % 60)s"
    }

    /// Whether a piece counts: the distance exactly (a monitor stops on it), or the time within the
    /// finish-line tolerance tests use (`erg_event_board` applies the same rule).
    func accepts(distanceM pieceDistance: Int, timeMs pieceTime: Int) -> Bool {
        if let distanceM { return pieceDistance == distanceM }
        guard let durationMs else { return false }
        return abs(pieceTime - durationMs) <= StandardTest.finishTolerance(forDurationMs: durationMs)
    }

    /// From its start until six hours after its end: a post can count for it.
    func isOpenForPosting(at now: Date) -> Bool {
        now >= startsAt && now <= endsAt.addingTimeInterval(Self.postingGrace)
    }

    /// A distance is raced on time (fastest first); a time on distance (furthest first).
    var isRacedOnTime: Bool { distanceM != nil }
}
