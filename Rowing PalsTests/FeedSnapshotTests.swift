//
//  FeedSnapshotTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// Renders a Feed post (comments, reactions and share in one row) and a single's boat card to PNGs,
/// to check them without a club's data (user, 2026-10-17). Writes to $TMPDIR/feed-*.png.
@MainActor
struct FeedSnapshotTests {
    private static func post() throws -> FeedPost {
        let me = UUID()
        let json = """
        {"id": "\(UUID())", "user_id": "\(me)", "type": "erg", "caption": "Steady state + rate ladder.",
         "workout_label": "UT2", "total_distance_m": 12000, "total_time_ms": 2848800, "avg_split_ms": 118700,
         "avg_rate": 20, "photo_verified": true, "logged_late": false, "is_new_pb": false,
         "posted_at": "2026-10-17T07:30:00Z",
         "profiles": {"display_name": "Piero Ciobanu", "category": "senior", "gender": "M", "avatar_path": null,
                      "clubs": {"name": "UEA Boat Club"}},
         "segments": [{"id": "\(UUID())", "label": "main", "position": 0, "distance_m": 12000, "time_ms": 2848800,
                       "split_ms": 118700, "monitor_photo_path": null, "is_lead": true}],
         "session_photos": [],
         "reactions": [{"kind": "fire", "user_id": "\(UUID())"}, {"kind": "fire", "user_id": "\(me)"},
                       {"kind": "muscle", "user_id": "\(UUID())"}],
         "comments": [{"count": 2}]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FeedPost.self, from: Data(json.utf8))
    }

    @Test func aPostKeepsReactionsBesideComments() throws {
        let reactions = [FeedViewModel.ReactionSummary(kind: "fire", count: 7, isMine: true),
                         FeedViewModel.ReactionSummary(kind: "muscle", count: 3, isMine: false)]
        let view = FeedCardView(post: try Self.post(), photoURL: { _ in nil }, selfieURL: nil, reactions: reactions)
            .padding(Tokens.Spacing.screen)
        try Self.render(view, name: "post")
    }

    @Test func aSingleIsJustTheBoat() throws {
        let session = WaterSession(id: UUID(), clubId: UUID(), practiceId: nil, eventId: nil, title: "Steady 12k",
                                   startsAt: Date().addingTimeInterval(86_400), meetAt: "the boathouse 06:45",
                                   plan: "12k steady, rate 20", createdBy: nil)
        let me = UUID()
        let boat = SessionBoat(id: UUID(), sessionId: session.id, name: "Single", boatType: .single, rigging: .stroke,
                               sentAt: Date(), seats: [BoatSeat(seat: 1, userId: me)])
        let view = FeedBoatCard(boat: boat, session: session, names: [me: "Piero Ciobanu"], coachName: "Piero Ciobanu", mySeat: 1)
            .padding(Tokens.Spacing.screen)
        try Self.render(view, name: "single")
    }

    private static func render(_ content: some View, name: String) throws {
        for scheme in [ColorScheme.dark, .light] {
            let renderer = ImageRenderer(content: content.frame(width: 393).background(Tokens.Base.ground).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("feed-\(name)-\(scheme == .dark ? "dark" : "light").png")
            try #require(image.pngData()).write(to: url)
            print("Feed snapshot: \(url.path)")
            #expect(image.size.width > 0)
        }
    }
}
