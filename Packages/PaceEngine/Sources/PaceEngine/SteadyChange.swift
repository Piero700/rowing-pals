//
//  SteadyChange.swift
//  PaceEngine
//
//  Port of `SteadyChange` and `_steady_change` (v1.7, SPEC.md §5.19).
//

import Foundation

/// How the rower's other pieces have moved since their newest all-out piece.
struct SteadyChange {
    /// After minus before, 2k-equivalent seconds per 500m (negative = faster).
    let changeS: Double
    let piecesBefore: Int
    let piecesAfter: Int
    let zones: [Tier.Name]

    /// `_steady_change`: every piece in a lower-ranked zone than the anchor, compared within
    /// its own zone — the duration-weighted median 2k equivalent after the measurement day
    /// minus the one on or before it — so the rower's personal gap between zones cancels.
    /// Zones combine by their minutes. Nil without enough pieces on both sides.
    static func measure(_ sessions: [Session], anchor: Anchor, config: EngineConfig,
                        paul: Double?) -> SteadyChange? {
        guard config.steadyTrend, let measuredDay = anchor.measuredDay else { return nil }
        let supporting = sessions.filter {
            !$0.declared && !$0.volumeOnly && $0.tier.rank > anchor.tier.rank
        }
        var changes: [(change: Double, minutes: Double)] = []
        var zones: [Tier.Name] = []
        var beforeCount = 0
        var afterCount = 0
        // Python iterates `sorted({tags}, key=rank)`: Tier.all is rank order.
        for tier in Tier.all where supporting.contains(where: { $0.tag == tier.name }) {
            let zone = supporting.filter { $0.tag == tier.name }
            let before: [(value: Double, weight: Double)] = zone.filter { $0.day <= measuredDay }
                .map { (pieceTwoK($0, config: config, paul: paul), $0.durationMinutes) }
            let after: [(value: Double, weight: Double)] = zone.filter { $0.day > measuredDay }
                .map { (pieceTwoK($0, config: config, paul: paul), $0.durationMinutes) }
            if before.isEmpty || after.isEmpty { continue }
            changes.append((weightedMedian(after) - weightedMedian(before),
                            Py.sum(zone.map(\.durationMinutes))))
            zones.append(tier.name)
            beforeCount += before.count
            afterCount += after.count
        }
        guard !changes.isEmpty, beforeCount >= config.steadyTrendMinPieces,
              afterCount >= config.steadyTrendMinPieces else { return nil }
        let minutes = Py.sum(changes.map(\.minutes))
        let change = minutes > 0 ? Py.sum(changes.map { $0.change * $0.minutes }) / minutes : 0.0
        return SteadyChange(changeS: change, piecesBefore: beforeCount, piecesAfter: afterCount,
                            zones: zones)
    }
}
