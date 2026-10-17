//
//  WaterCalendarScope.swift
//  Rowing Pals
//

/// Which water sessions the rower's Calendar shows (decision 79): the ones they're seated in, or the
/// whole club's. Only the owner, co-owners, admins and coaches who row can choose (Settings →
/// Boats); everyone else sees their own. Kept on the phone, like `BoatOrientation`.
enum WaterCalendarScope: String, CaseIterable {
    case mine, club

    static let storageKey = "waterCalendarScope"

    var label: String {
        switch self {
        case .mine: "Mine"
        case .club: "Whole club"
        }
    }

    /// Whether this person may see the whole club's water sessions: a coach, or the owner, a
    /// co-owner or an admin (as the database's `can_see_club_water`).
    static func canChoose(isCoach: Bool, clubRole: ClubRole) -> Bool {
        isCoach || clubRole >= .admin
    }

    /// What the Calendar loads: the chosen scope for those who may choose, else their own.
    static func resolved(_ preferred: WaterCalendarScope, isCoach: Bool, clubRole: ClubRole) -> WaterCalendarScope {
        canChoose(isCoach: isCoach, clubRole: clubRole) ? preferred : .mine
    }
}
