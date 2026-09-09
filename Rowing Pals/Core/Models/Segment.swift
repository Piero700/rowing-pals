//
//  Segment.swift
//  Rowing Pals
//

import Foundation

/// Mirrors the `segments` table in docs/schema.sql. One monitor photo; a
/// session has one or more.
struct Segment: Codable, Identifiable {
    let id: UUID
    var sessionId: UUID
    var label: SegmentLabel
    var position: Int
    var distanceM: Int
    var timeMs: Int
    var splitMs: Int?
    var rate: Double?
    var monitorPhotoPath: String?
    /// 0.0–1.0, nil for manual entry.
    var ocrConfidence: Double?
    var wasEdited: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case label, position
        case distanceM = "distance_m"
        case timeMs = "time_ms"
        case splitMs = "split_ms"
        case rate
        case monitorPhotoPath = "monitor_photo_path"
        case ocrConfidence = "ocr_confidence"
        case wasEdited = "was_edited"
    }
}
