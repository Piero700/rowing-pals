//
//  SwipeBackNavigation.swift
//  Rowing Pals
//

import ObjectiveC
import UIKit

/// Swipe back from the left edge on every pushed screen, as in Safari (decision 61, user
/// 2026-10-14: "a universal feature all through the app", including screens added later).
///
/// The app's screens draw their own back button and hide the system bar, and iOS turns its
/// edge-swipe-back off when it does that. Every `NavigationStack` is a `UINavigationController`
/// underneath, so this turns it back on for all of them, now and in future: the swipe is allowed
/// whenever there's a screen to go back to. Screens shown over everything (a full-screen cover)
/// aren't pushed; they close with `edgeSwipeToDismiss()` instead (see `RouteHost`).
extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        let delegate = SwipeBackDelegate(navigationController: self)
        objc_setAssociatedObject(self, &SwipeBackDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        interactivePopGestureRecognizer?.delegate = delegate
    }
}

/// Lets the edge swipe start whenever there's a screen to go back to and no transition is
/// already running.
private final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    nonisolated(unsafe) static var key: UInt8 = 0
    weak var navigationController: UINavigationController?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController else { return false }
        return navigationController.viewControllers.count > 1 && navigationController.transitionCoordinator == nil
    }
}
