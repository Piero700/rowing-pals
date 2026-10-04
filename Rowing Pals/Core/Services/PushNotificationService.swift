//
//  PushNotificationService.swift
//  Rowing Pals
//

import Foundation
import os
import Supabase
import UIKit
import UserNotifications

/// The phone's side of push notifications (docs/design/v2-decisions.md #19): asks iOS for
/// permission, hands Apple's device token to Supabase so the `send-push` Edge Function can
/// reach this phone, and turns a tapped alert into a route for `RootView` to open.
///
/// What gets sent, to whom and when is decided server-side
/// (docs/migrations/2026-09-26-notifications.sql). Receiving anything also needs the Push
/// Notifications capability, which Apple only grants to a paid developer account; until
/// then registration fails quietly and everything else still works.
@Observable
final class PushNotificationService {
    static let shared = PushNotificationService()

    /// A post opened from an alert. `RootView` presents it, then clears this.
    var pendingRoute: AppRoute?
    /// Whether iOS lets this app show alerts — Settings explains when it doesn't.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private static let tokenKey = "push.deviceToken"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RowingPals", category: "push")

    private init() {}

    /// The last token Apple gave this phone, kept so signing out can withdraw it.
    private var deviceToken: String? {
        get { UserDefaults.standard.string(forKey: Self.tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.tokenKey) }
    }

    /// Runs each time the signed-in app appears. iOS shows its permission prompt only the
    /// first time; after that this just re-registers (Apple can change the token) and keeps
    /// the rower's time zone current for quiet hours.
    func start() async {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                logger.error("Permission request failed: \(error.localizedDescription)")
            }
        }
        await refreshAuthorizationStatus()
        if canAlert {
            UIApplication.shared.registerForRemoteNotifications()
        }
        await syncTimeZone()
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    var canAlert: Bool {
        [.authorized, .provisional, .ephemeral].contains(authorizationStatus)
    }

    /// Apple's token for this phone, stored against the signed-in rower. A token another
    /// rower registered on this phone moves to this one.
    func didRegister(deviceToken data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        struct Params: Encodable {
            let token: String
            let bundleId: String
            enum CodingKeys: String, CodingKey {
                case token = "p_token"
                case bundleId = "p_bundle_id"
            }
        }
        do {
            try await SupabaseService.shared
                .rpc("register_device_token", params: Params(token: token, bundleId: Bundle.main.bundleIdentifier ?? ""))
                .execute()
        } catch {
            logger.error("Registering the device token failed: \(error.localizedDescription)")
        }
    }

    func didFailToRegister(_ error: Error) {
        // Expected until the app has the Push Notifications capability (paid developer account).
        logger.notice("Push registration unavailable: \(error.localizedDescription)")
    }

    /// Stops alerts reaching this phone. Called before signing out, while still signed in.
    func unregisterThisDevice() async {
        guard let token = deviceToken else { return }
        struct Params: Encodable {
            let token: String
            enum CodingKeys: String, CodingKey { case token = "p_token" }
        }
        do {
            try await SupabaseService.shared.rpc("unregister_device_token", params: Params(token: token)).execute()
        } catch {
            logger.error("Withdrawing the device token failed: \(error.localizedDescription)")
        }
    }

    /// Only the zone is written, so a rower's other choices are never overwritten.
    func syncTimeZone() async {
        guard let userId = try? await SupabaseService.shared.auth.session.user.id else { return }
        struct Row: Encodable {
            let userId: UUID
            let timeZone: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case timeZone = "time_zone"
            }
        }
        do {
            try await SupabaseService.shared
                .from("notification_settings")
                .upsert(Row(userId: userId, timeZone: TimeZone.current.identifier), onConflict: "user_id")
                .execute()
        } catch {
            logger.error("Saving the time zone failed: \(error.localizedDescription)")
        }
    }

    /// A tapped alert opens its post (`session_id`), or — for a club invitation — Your club,
    /// where it can be accepted or declined (see send-push, decision 26).
    func open(sessionId: String?, kind: String?) {
        if kind == "club_invite" {
            pendingRoute = .clubHub
            return
        }
        guard let sessionId, let id = UUID(uuidString: sessionId) else { return }
        pendingRoute = .post(id)
    }
}
