//
//  Notification+ClubChanged.swift
//  Rowing Pals
//

import Foundation

extension Notification.Name {
    /// The signed-in rower joined a club after onboarding without one (decision 24). The
    /// feed and rankings reload, as the Club tab and My club board now have a club to show.
    static let rowerClubChanged = Notification.Name("rowerClubChanged")
}
