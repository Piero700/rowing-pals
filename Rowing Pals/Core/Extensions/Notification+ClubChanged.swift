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
}

extension NotificationCenter {
    /// Announces a club change. The shared viewer context is cleared first, so every screen
    /// that reloads on the notification reads the new club rather than the cached one.
    func postRowerClubChanged() {
        ViewerContext.shared.invalidate()
        post(name: .rowerClubChanged, object: nil)
    }
}
