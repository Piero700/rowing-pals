//
//  BoatOrientation.swift
//  Rowing Pals
//

/// How boats are drawn (Settings → Boats → Draw boats; decision 74): stern at the top, so a crew
/// reads stroke first, or bow at the top. Each person picks their own; stern first unless they
/// change it.
nonisolated enum BoatOrientation: String, CaseIterable {
    case sternAtTop = "stern"
    case bowAtTop = "bow"

    static let storageKey = "boatOrientation"

    var label: String { self == .sternAtTop ? "Stern at the top" : "Bow at the top" }
}
