//
//  AppDelegate.swift
//  Rowing Pals
//

import UIKit
import UserNotifications

/// The two things push notifications still need UIKit for: Apple's device-token callbacks,
/// and being told when an alert is shown or tapped. Everything else lives in
/// `PushNotificationService`.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set before launch finishes, so a tap that launched the app is still delivered.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await PushNotificationService.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationService.shared.didFailToRegister(error)
    }

    /// With the app open, an alert still shows as a banner rather than vanishing.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Tapping an alert opens its post, practice or race, or Your club for an invitation.
    ///
    /// On the main actor, not `nonisolated`: iOS is told the tap is handled when this returns, and
    /// UIKit aborts the app if that happens off the main thread (the crash on tapping a "Your boat"
    /// alert, 2026-10-18).
    @MainActor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        PushNotificationService.shared.open(
            sessionId: userInfo["session_id"] as? String,
            kind: userInfo["kind"] as? String,
            practiceId: userInfo["practice_id"] as? String,
            eventId: userInfo["event_id"] as? String
        )
    }
}
