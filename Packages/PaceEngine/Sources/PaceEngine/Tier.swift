//
//  Tier.swift
//  PaceEngine
//
//  Port of `Tier` and `TIERS` in pace_engine.py. Constants unchanged.
//

import Foundation

/// Physiological constants for one training intensity zone.
///
/// Every observed session is modelled as
/// `observed_split(d, T) = S2k + w_T × 5 × log2(d / ref_T) + g_T` (SPEC.md §2), where
/// `w_T` is `paulWeight`, `ref_T` is `refDistanceM` and `g_T` is `offset`. Quoting the offset
/// at the tier's own reference distance is what stops the distance discount being counted
/// twice (SPEC.md §8.1–8.2).
public struct Tier: Sendable, Equatable {
    /// The five zones, spelled as the engine, its flags and its output spell them.
    public enum Name: String, Sendable, CaseIterable, Codable {
        case an = "AN"
        case tr = "TR"
        case at = "AT"
        case ut1 = "UT1"
        case ut2 = "UT2"
    }

    public let name: Name
    /// TRIMP-lite intensity multiplier, applied to session duration in minutes.
    public let load: Double
    /// Seconds per 500m this tier sits above maximal 2000m pace, measured at `refDistanceM`.
    public let offset: Double
    /// The distance at which `offset` is quoted — the tier's typical session or rep length.
    public let refDistanceM: Double
    /// How strongly this tier's pace decays with distance, as a fraction of Paul's Law.
    public let paulWeight: Double
    /// Plausible average stroke rate; outside it the tag is probably wrong.
    public let rateLo: Double
    public let rateHi: Double
    /// Plausible session RPE on the Borg CR10 scale.
    public let rpeLo: Double
    public let rpeHi: Double
    /// Anchor selection priority, lower is better.
    public let rank: Int

    public var rpeMid: Double { (rpeLo + rpeHi) / 2.0 }

    /// AN and TR (`MAXIMAL_TIERS`): anchored by the single closest-distance session.
    public var isMaximal: Bool { name == .an || name == .tr }

    // Seed calibration. Verified mutually consistent for a 1:45.0 2k athlete by the Python
    // reference's `_check_tier_coherence` self-test.
    public static let an = Tier(name: .an, load: 3.0, offset: 0.0, refDistanceM: 2000.0,
                                paulWeight: 1.00, rateLo: 28.0, rateHi: 44.0,
                                rpeLo: 9.0, rpeHi: 10.0, rank: 1)
    public static let tr = Tier(name: .tr, load: 2.0, offset: 8.0, refDistanceM: 4000.0,
                                paulWeight: 0.85, rateLo: 26.0, rateHi: 36.0,
                                rpeLo: 7.0, rpeHi: 8.5, rank: 2)
    public static let at = Tier(name: .at, load: 1.5, offset: 13.0, refDistanceM: 8000.0,
                                paulWeight: 0.50, rateLo: 20.0, rateHi: 30.0,
                                rpeLo: 5.5, rpeHi: 7.0, rank: 3)
    public static let ut1 = Tier(name: .ut1, load: 1.2, offset: 17.0, refDistanceM: 12000.0,
                                 paulWeight: 0.25, rateLo: 18.0, rateHi: 26.0,
                                 rpeLo: 4.0, rpeHi: 5.5, rank: 4)
    public static let ut2 = Tier(name: .ut2, load: 1.0, offset: 22.0, refDistanceM: 16000.0,
                                 paulWeight: 0.15, rateLo: 14.0, rateHi: 22.0,
                                 rpeLo: 2.0, rpeHi: 4.0, rank: 5)

    /// Every tier in rank order — also the iteration order of the Python `TIERS` dict.
    public static let all: [Tier] = [an, tr, at, ut1, ut2]

    public static func named(_ name: Name) -> Tier {
        switch name {
        case .an: an
        case .tr: tr
        case .at: at
        case .ut1: ut1
        case .ut2: ut2
        }
    }
}
