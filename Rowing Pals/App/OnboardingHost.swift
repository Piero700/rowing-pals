//
//  OnboardingHost.swift
//  Rowing Pals
//

import SwiftUI

/// Onboarding's first step (`ClubSearchView`) before the app's own `RouteHost` exists. It answers
/// the one route onboarding raises — **Create a club** (decision 98) — by covering the screen with
/// the club form; once the club is made, ClubSearchView sees the club change and goes on to
/// About you with the new rower as its owner.
struct OnboardingHost: View {
    @State private var isCreatingClub = false

    var body: some View {
        ClubSearchView()
            .environment(\.navigate, NavigateAction { route in
                if case .createClub = route { isCreatingClub = true }
            })
            .fullScreenCover(isPresented: $isCreatingClub) {
                NavigationStack {
                    ClubFormView(mode: .create)
                }
                .edgeSwipeToDismiss()
            }
    }
}
