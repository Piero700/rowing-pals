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
///
/// Two of the controller's gestures do it, both driving the system's own interactive pop:
/// - `interactivePopGestureRecognizer`, the screen-edge pan. It only starts from a band a few
///   points wide at the very edge, so on its own a swipe that starts a little way in does nothing.
/// - `interactiveContentPopGestureRecognizer` (iOS 26), kept to the same band as
///   `edgeSwipeToDismiss()` (`Tokens.Size.swipeBackEdge`). Without it, the first screen of an area
///   swiped away from 24 points in but the screens pushed on top of it didn't (2026-11-05:
///   Workouts → results → rower or notepad).
extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        let delegate = SwipeBackDelegate(navigationController: self)
        objc_setAssociatedObject(self, &SwipeBackDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        interactivePopGestureRecognizer?.delegate = delegate
        interactiveContentPopGestureRecognizer?.delegate = delegate
    }
}

/// Lets the swipe start whenever there's a screen to go back to and no transition is already
/// running; the content swipe also has to start near the left edge and move right.
private final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    nonisolated(unsafe) static var key: UInt8 = 0
    weak var navigationController: UINavigationController?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard isContentSwipe(gestureRecognizer) else { return true }
        return touch.location(in: gestureRecognizer.view).x <= Tokens.Size.swipeBackEdge
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController,
              navigationController.viewControllers.count > 1,
              navigationController.transitionCoordinator == nil else { return false }
        guard isContentSwipe(gestureRecognizer) else { return true }
        // Only a swipe to the right, and more across than down, so scrolling still scrolls.
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        let velocity = pan.velocity(in: pan.view)
        return velocity.x > 0 && abs(velocity.x) > abs(velocity.y)
    }

    private func isContentSwipe(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === navigationController?.interactiveContentPopGestureRecognizer
    }
}
