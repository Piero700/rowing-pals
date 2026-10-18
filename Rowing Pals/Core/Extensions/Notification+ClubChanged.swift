//
//  Notification+ClubChanged.swift
//  Rowing Pals
//

import Foundation

extension Notification.Name {
    /// The signed-in rower's club changed — joined, left, created, deleted or edited
    /// (decisions 24–25) — or their coaching status or account type did (decisions 34, 39).
    /// The feed, rankings, profile and tab bar reload.
    static let rowerClubChanged = Notification.Name("rowerClubChanged")
    /// The signed-in rower just posted a session: the feed reloads, and a workout it was posted
    /// for leaves the Feed (decision 57).
    static let sessionPosted = Notification.Name("sessionPosted")
    /// The signed-in rower deleted one of their posts (decision 63); `object` is its id.
    static let sessionDeleted = Notification.Name("sessionDeleted")
    /// The signed-in rower answered a practice or a race away from the Calendar (its page, the
    /// Feed's card); the Calendar and Feed reload (decision 68).
    static let practiceAnswered = Notification.Name("practiceAnswered")
    /// A coach changed the calendar — a practice, a race, the register or the club's week — from
    /// a screen over their Calendar tab, which reloads.
    static let calendarChanged = Notification.Name("calendarChanged")
    /// A coach saved, sent or deleted a water session or a boat (decision 67): the Boats tab, the
    /// session and the Calendar reload.
    static let boatsChanged = Notification.Name("boatsChanged")
    /// An announcement was posted, changed or deleted (decision 75): the Feed and Calendar reload.
    static let announcementsChanged = Notification.Name("announcementsChanged")
    /// Who a post's author trained with changed (decision 90); `object` is the post's id.
    static let tagsChanged = Notification.Name("tagsChanged")
}

extension NotificationCenter {
    /// Announces a club change. The shared viewer context is cleared first, so every screen
    /// that reloads on the notification reads the new club rather than the cached one.
    func postRowerClubChanged() {
        ViewerContext.shared.invalidate()
        post(name: .rowerClubChanged, object: nil)
    }
}
