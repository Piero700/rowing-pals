//
//  MonitorRow.swift
//  Rowing Pals
//

import Foundation

/// One row of a monitor's results table, read off a photo for the coach notepad (decision 96,
/// phase NP2): the summary row under the header, or one interval below it. Any field can be nil
/// when glare or a dim screen hid it. Never stored as it is: the notepad keeps only the scores a
/// coach fills from it.
nonisolated struct MonitorRow: Equatable {
    var timeMs: Int?
    var distanceM: Int?
    var splitMs: Int?
    var rate: Int?
    /// The row's number, when the monitor prints one to the left of the time.
    var number: Int?
    /// The total row directly under the header, not an interval.
    var isSummary = false

    /// Whether split × metres ÷ 500 comes to the time, as the monitor's own sums do (it truncates
    /// the split to the tenth, so the time may run up to 0.1 s per 500 m over, plus its own tenth).
    /// Picks the right reading when two screens disagree about one row.
    var addsUp: Bool {
        guard let timeMs, let distanceM, let splitMs, distanceM > 0 else { return false }
        let predicted = splitMs * distanceM / 500
        return (predicted - 100...predicted + 100 * distanceM / 500 + 100).contains(timeMs)
    }
}
