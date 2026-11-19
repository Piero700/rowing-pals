//
//  ShareCardRow.swift
//  Rowing Pals
//

import Foundation

/// One line on a shared week card or workout card (decision 110).
nonisolated struct ShareCardRow: Equatable, Identifiable {
    let id: String
    let start: Date
    /// "Tue".
    let dayText: String
    /// "06:30", or nil for a row with no set time.
    let timeText: String?
    let title: String
    let detail: String?
}
