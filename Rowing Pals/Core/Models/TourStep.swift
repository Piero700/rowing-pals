//
//  TourStep.swift
//  Rowing Pals
//

import Foundation

/// One card of the first-run tour (decision 109): what it points at on the tab bar, and what it says.
nonisolated struct TourStep: Identifiable, Equatable, Sendable {
    /// The tab bar control the card points at: a tab by its label ("Feed"), or the Log / + button.
    enum Target: Hashable, Sendable {
        case tab(String)
        case newButton
    }

    let target: Target
    let title: String
    let body: String

    var id: Target { target }
}
