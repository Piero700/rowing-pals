//
//  AnnouncementSnapshotTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// Renders the Feed's announcement cards, folded and open, to PNGs to compare with the canvas
/// (RowerFeedAnnouncement) without a club's data. Writes to $TMPDIR/announcements-*.png.
@MainActor
struct AnnouncementSnapshotTests {
    @Test func feedCardsRender() throws {
        let open = Announcement(id: UUID(), clubId: UUID(), heading: "Kit order closes Friday",
                                message: "Club kit orders close this Friday at 18:00. Sizes are on the noticeboard in the boathouse; pay on the club account and put your name in the reference.",
                                expiresAt: Date().addingTimeInterval(86_400), createdBy: nil, createdAt: Date())
        let folded = Announcement(id: UUID(), clubId: UUID(), heading: "Boathouse closed Sunday morning", message: "No outings before 12:00.",
                                  expiresAt: Date().addingTimeInterval(3 * 86_400), createdBy: nil, createdAt: Date().addingTimeInterval(-86_400))
        let view = VStack(spacing: Tokens.Spacing.tight) {
            FeedAnnouncementCard(announcement: open, meta: "Sarah Lin · today", isExpanded: true, canEdit: true, onToggle: {}, onEdit: {})
            FeedAnnouncementCard(announcement: folded, meta: "Tom Ashworth · yesterday", isExpanded: false, canEdit: false, onToggle: {}, onEdit: {})
        }
        .padding(Tokens.Spacing.screen)
        for scheme in [ColorScheme.dark, .light] {
            let renderer = ImageRenderer(content: view.frame(width: 393).background(Tokens.Base.ground).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("announcements-\(scheme == .dark ? "dark" : "light").png")
            try #require(image.pngData()).write(to: url)
            print("Announcements snapshot: \(url.path)")
            #expect(image.size.width > 0)
        }
    }
}
