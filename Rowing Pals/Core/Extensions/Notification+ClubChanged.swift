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
}

extension NotificationCenter {
    /// Announces a club change. The shared viewer context is cleared first, so every screen
    /// that reloads on the notification reads the new club rather than the cached one.
    func postRowerClubChanged() {
        ViewerContext.shared.invalidate()
        post(name: .rowerClubChanged, object: nil)
    }
}
