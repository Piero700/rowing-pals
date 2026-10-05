//
//  FeedPost.swift
//  Rowing Pals
//

import Foundation

/// One feed card's worth of data — a `sessions` row joined to its author's `profiles` row (and
/// that profile's `clubs` row), its `segments`, its extra `session_photos`, its `reactions` and
/// its comment count, in one PostgREST query. Feed-local, not a `Core/Models` table mirror.
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
        let timeMs: Int
        let splitMs: Int?
        let monitorPhotoPath: String?
        /// The piece that leads the post (docs/design/v2-decisions.md #10).
        let isLead: Bool

        enum CodingKeys: String, CodingKey {
            case id, label, position
            case distanceM = "distance_m"
            case timeMs = "time_ms"
            case splitMs = "split_ms"
            case monitorPhotoPath = "monitor_photo_path"
            case isLead = "is_lead"
        }
    }

    struct SessionPhoto: Decodable {
        let position: Int
        let path: String
    }

    /// One `reactions` row, kept whole so the card can tell which are the viewer's own.
    struct ReactionRow: Decodable, Equatable {
        let kind: String
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case kind
            case userId = "user_id"
        }
    }

    /// PostgREST's shape for an embedded `count` aggregate: `[{"count": n}]`.
    struct CountRow: Decodable {
        let count: Int
    }

    /// One page of the photo carousel.
    struct Page: Identifiable {
        enum Kind {
            /// A piece's monitor photo; the lead piece's page also carries the selfie inset.
            case monitor(Segment)
            /// A photo with no monitor in it.
            case environment
        }
        let id: String
        let path: String
        let kind: Kind
    }

    let id: UUID
    let userId: UUID
    let type: SessionType
    let caption: String?
    /// Badge text for the Main piece ("UT2", "2k test"…). Nil on posts made before phase F.
    let workoutLabel: String?
    let totalDistanceM: Int
    let totalTimeMs: Int
    let avgSplitMs: Int?
    let avgRate: Double?
    let photoVerified: Bool
    let loggedLate: Bool
    /// The session's test result beat the rower's previous best (decision 12).
    let isNewPB: Bool
    let postedAt: Date
    let author: Author
    let segments: [Segment]
    let sessionPhotos: [SessionPhoto]
    /// Mutable so the feed can apply a reaction the moment it's tapped.
    var reactions: [ReactionRow]
    /// Mutable so the card's count follows a comment written from the feed.
    var commentCounts: [CountRow]

    var commentCount: Int { commentCounts.first?.count ?? 0 }

    var orderedSegments: [Segment] { segments.sorted { $0.position < $1.position } }

    /// The piece the card leads with: the one marked as lead, else Main, else the first.
    var leadSegment: Segment? {
        segments.first(where: \.isLead)
            ?? segments.first(where: { $0.label == .main })
            ?? orderedSegments.first
    }

    /// The lead piece's own numbers (decision 16) — the most intense piece, not the whole
    /// session — falling back to the session's when it has no pieces. Shown on the card and
    /// the share image.
    var leadDistanceM: Int { leadSegment?.distanceM ?? totalDistanceM }
    var leadTimeMs: Int { leadSegment?.timeMs ?? totalTimeMs }
    /// Nil when unknown: a zero split means a piece with no distance or time.
    var leadSplitMs: Int? { (leadSegment?.splitMs ?? avgSplitMs).flatMap { $0 > 0 ? $0 : nil } }

    /// Carousel order (decision 11): the lead piece's monitor photo first, then the other
    /// pieces' monitor photos in position order, then the environment photos.
    var pages: [Page] {
        var result: [Page] = []
        if let lead = leadSegment, let path = lead.monitorPhotoPath {
            result.append(Page(id: path, path: path, kind: .monitor(lead)))
        }
        for segment in orderedSegments where segment.id != leadSegment?.id {
            if let path = segment.monitorPhotoPath {
                result.append(Page(id: path, path: path, kind: .monitor(segment)))
            }
        }
        for photo in sessionPhotos.sorted(by: { $0.position < $1.position }) {
            result.append(Page(id: photo.path, path: photo.path, kind: .environment))
        }
        return result
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type, caption
        case workoutLabel = "workout_label"
        case totalDistanceM = "total_distance_m"
        case totalTimeMs = "total_time_ms"
        case avgSplitMs = "avg_split_ms"
        case avgRate = "avg_rate"
        case photoVerified = "photo_verified"
        case loggedLate = "logged_late"
        case isNewPB = "is_new_pb"
        case postedAt = "posted_at"
        case author = "profiles"
        case segments
        case sessionPhotos = "session_photos"
        case reactions
        case commentCounts = "comments"
    }
}
