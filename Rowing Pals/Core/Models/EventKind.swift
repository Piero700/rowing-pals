//
//  EventKind.swift
//  Rowing Pals
//

/// A race or regatta, or another club event — a meeting, social or kit day (decision 68).
nonisolated enum EventKind: String, Codable, CaseIterable {
    case race, event

    var label: String { self == .race ? "Race or regatta" : "Other event" }
}
