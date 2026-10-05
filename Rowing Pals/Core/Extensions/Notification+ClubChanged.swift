//
//  Notification+ClubChanged.swift
//  Rowing Pals
//

import Foundation

extension Notification.Name {
    /// The signed-in rower's club changed — joined, left, created, deleted or edited
    /// (decisions 24–25). The feed, rankings and profile reload.
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
