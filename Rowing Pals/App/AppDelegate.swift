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

    /// Tapping an alert opens its post.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let sessionId = response.notification.request.content.userInfo["session_id"] as? String
        await MainActor.run {
            PushNotificationService.shared.open(sessionId: sessionId)
        }
    }
}
