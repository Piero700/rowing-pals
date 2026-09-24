//
//  RouteHost.swift
//  Rowing Pals
//

import SwiftUI

/// Presents an `AppRoute` over the tabs and keeps a navigation stack for
/// everything reachable from it: profile → followers → another profile →
/// and so on. `App/` is the one layer allowed to know every feature, so this
/// is where routes become screens — features themselves only raise routes
/// (CLAUDE.md: no feature imports another feature).
struct RouteHost: View {
    let root: AppRoute

    @State private var path: [AppRoute] = []
    @Environment(\.dismiss) private var dismiss
    /// The tab bar's scroll-tracking state belongs to the tabs; a profile in
    /// here gets its own so scrolling it doesn't move a bar that isn't
    /// on screen.
    @State private var barVisibility = FloatingBarVisibility()

    var body: some View {
        NavigationStack(path: $path) {
            destination(root)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .accessibilityLabel("Close")
                    }
                }
                .navigationDestination(for: AppRoute.self) { route in
                    destination(route)
                }
        }
        .tint(Tokens.Accent.brand)
        .environment(barVisibility)
        .environment(\.navigate, NavigateAction { path.append($0) })
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .profile(let userId):
            ProfileView(viewing: userId)
        case .people(let kind):
            PeopleListView(kind: kind)
        case .followRequests:
            FollowRequestsView()
        }
    }
}
