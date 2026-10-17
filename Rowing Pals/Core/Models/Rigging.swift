//
//  Rigging.swift
//  Rowing Pals
//

/// Which side each oar is on in a sweep boat (decisions 67, 74): stroke-rigged puts the stroke's oar
/// on stroke side and the seats alternate from there; bow-rigged is the other way round; custom
/// keeps a side for every seat, for a bucket rig or any other staggered setup.
nonisolated enum Rigging: String, Codable, CaseIterable {
    case stroke, bow, custom

    var label: String {
        switch self {
        case .stroke: "Stroke-rigged"
        case .bow: "Bow-rigged"
        case .custom: "Custom"
        }
    }
}
