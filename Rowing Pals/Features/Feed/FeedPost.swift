//
//  FeedPost.swift
//  Rowing Pals
//

import Foundation

/// One feed card's worth of data — a `sessions` row joined to its author's
/// `profiles` row (and that profile's `clubs` row) and its `segments`, in
/// one PostgREST query. Feed-local, not a `Core/Models` table mirror: it's
/// a read-shape projection across four tables, not one row.
struct FeedPost: Decodable, Identifiable {
    struct Author: Decodable {
        struct Club: Decodable {
            let name: String
        }

        let displayName: String
        let category: RowerCategory
        let gender: RowerGender?
        let avatarPath: String?
        let club: Club?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case category, gender
            case avatarPath = "avatar_path"
            case club = "clubs"
        }
    }

    struct Segment: Decodable, Identifiable {
        let id: UUID
        let label: SegmentLabel
        let position: Int
        let distanceM: Int
        let monitorPhotoPath: String?

        enum CodingKeys: String, CodingKey {
            case id, label, position
            case distanceM = "distance_m"
            case monitorPhotoPath = "monitor_photo_path"
        }
    }

    let id: UUID
    let userId: UUID
    let type: SessionType
    let caption: String?
    let totalDistanceM: Int
    let totalTimeMs: Int
    let avgSplitMs: Int?
    let avgRate: Double?
    let photoVerified: Bool
    let loggedLate: Bool
    let postedAt: Date
    let author: Author
    let segments: [Segment]

    /// The card's one full-bleed monitor photo — the first segment shot,
    /// since a session can have several but the design brief's card shows
    /// only one.
    var primarySegment: Segment? {
        segments.min { $0.position < $1.position }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type, caption
        case totalDistanceM = "total_distance_m"
        case totalTimeMs = "total_time_ms"
        case avgSplitMs = "avg_split_ms"
        case avgRate = "avg_rate"
        case photoVerified = "photo_verified"
        case loggedLate = "logged_late"
        case postedAt = "posted_at"
        case author = "profiles"
        case segments
    }
}
