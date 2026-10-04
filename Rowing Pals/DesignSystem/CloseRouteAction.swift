//
//  CloseRouteAction.swift
//  Rowing Pals
//

import SwiftUI

/// Closes the whole route screen (everything opened over the tabs), however deep the rower
/// has gone inside it — `dismiss` only steps back one screen. Set by `RouteHost`. Used when a
/// club accepts a waiting rower: they go straight back to where they started (decision 26).
struct CloseRouteAction {
    fileprivate let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func callAsFunction() {
        handler()
    }
}

private struct CloseRouteKey: EnvironmentKey {
    static let defaultValue = CloseRouteAction {}
}

extension EnvironmentValues {
    var closeRoute: CloseRouteAction {
        get { self[CloseRouteKey.self] }
        set { self[CloseRouteKey.self] = newValue }
    }
}
