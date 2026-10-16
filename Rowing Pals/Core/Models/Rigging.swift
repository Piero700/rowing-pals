//
//  Rigging.swift
//  Rowing Pals
//

/// Which side the stroke's oar is on in a sweep boat (decision 67): stroke-rigged puts it on
/// stroke side and the seats alternate from there; bow-rigged is the other way round.
nonisolated enum Rigging: String, Codable, CaseIterable {
    case stroke, bow

    var label: String { self == .stroke ? "Stroke-rigged" : "Bow-rigged" }
}
