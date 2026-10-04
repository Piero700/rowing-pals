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
