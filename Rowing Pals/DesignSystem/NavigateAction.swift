//
//  NavigateAction.swift
//  Rowing Pals
//

import SwiftUI

/// Raises an `AppRoute` to whoever owns navigation — `RootView` for the tab
/// screens, or the profile route host once a profile is already open.
/// Features call `navigate(.profile(id))` and never reference the screen
/// itself, which keeps "no feature imports another feature" true.
struct NavigateAction {
    fileprivate let handler: (AppRoute) -> Void

    init(_ handler: @escaping (AppRoute) -> Void) {
        self.handler = handler
    }

    func callAsFunction(_ route: AppRoute) {
        handler(route)
    }
}

private struct NavigateKey: EnvironmentKey {
    /// A no-op by default so a screen previewed on its own still works.
    static let defaultValue = NavigateAction { _ in }
}

extension EnvironmentValues {
    var navigate: NavigateAction {
        get { self[NavigateKey.self] }
        set { self[NavigateKey.self] = newValue }
    }
}
