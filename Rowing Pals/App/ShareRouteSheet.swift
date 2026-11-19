//
//  ShareRouteSheet.swift
//  Rowing Pals
//

import SwiftUI

/// The sheet a `.shareWeek` or `.shareWorkout` route opens (decision 110). Calendar and Coaching
/// only raise the route; `App/` turns it into the Share feature's sheet, so neither feature
/// references another (CLAUDE.md).
struct ShareRouteSheet: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .shareWeek: ShareWeekSheet(mode: .week)
        case .shareWorkout(let workoutId): ShareWeekSheet(mode: .workout(workoutId))
        default: EmptyView()
        }
    }
}
