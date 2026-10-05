//
//  AlertRoutePresenter.swift
//  Rowing Pals
//

import SwiftUI
import UIKit

/// Opens a tapped push alert's post above whatever is on screen — Settings, a comments sheet,
/// Log with a half-finished post — and closing it returns there (docs/design/
/// v2-decisions.md #19). `RootView`'s own full-screen cover can't do this: SwiftUI won't
/// present from a view while something above it is already presented, and it doesn't retry.
/// Nothing on screen is dismissed, so no draft is ever lost to an alert.
enum AlertRoutePresenter {
    /// False when there's no window to present from yet; the caller keeps the route and tries again.
    @discardableResult
    static func present(_ route: AppRoute, colorScheme: ColorScheme?) -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard var top = scene?.keyWindow?.rootViewController else { return false }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        let host = UIHostingController(rootView: RouteHost(root: route).preferredColorScheme(colorScheme))
        host.modalPresentationStyle = .fullScreen
        top.present(host, animated: true)
        return true
    }
}
