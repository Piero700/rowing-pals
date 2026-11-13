//
//  FeedAnnouncementsModel.swift
//  Rowing Pals
//

import Foundation

/// The announcements at the top of the Feed (decision 75): the club's that are still up, newest
/// first, who posted each, and whether this person may edit them (coaches, the owner, co-owners).
@MainActor
@Observable
final class FeedAnnouncementsModel {
    private(set) var announcements: [Announcement] = []
    private(set) var authorNames: [UUID: String] = [:]
    private(set) var canManage = false

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            guard viewer.clubId != nil else { announcements = []; return }
            canManage = AnnouncementRules.canManage(isCoach: viewer.isCoach, role: viewer.clubRole)
            let live = try await AnnouncementService.live()
            let unknown = Set(live.compactMap(\.createdBy).filter { authorNames[$0] == nil })
            if let found = try? await CalendarService.displayNames(of: unknown) {
                authorNames.merge(found) { _, new in new }
            }
            announcements = live
        } catch {
            // A failed or cancelled load keeps what's shown (as the boats, user 2026-10-18).
        }
    }

    /// "Sarah Lin · today".
    func meta(_ announcement: Announcement) -> String {
        let posted = AnnouncementRules.postedText(announcement.createdAt, now: Date(), calendar: .current)
        guard let author = announcement.createdBy, let name = authorNames[author] else { return posted.capitalized }
        return "\(name) · \(posted)"
    }
}
