//
//  SegmentLabel.swift
//  Rowing Pals
//

/// Mirrors the `segment_label` enum in docs/schema.sql.
enum SegmentLabel: String, Codable, CaseIterable {
    case warmup
    case main
    case cooldown
    case extra
}
