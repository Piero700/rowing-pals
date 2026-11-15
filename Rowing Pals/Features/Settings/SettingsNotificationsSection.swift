//
//  SettingsNotificationsSection.swift
//  Rowing Pals
//

import SwiftUI

/// v3 §07 Notifications: the alert switches (docs/design/v2-decisions.md #19; Quiet hours removed by
/// #36). If iOS has alerts turned off for the app, a first row says so and opens the page in the iOS
/// Settings app where they're turned back on — the switches alone can't override iOS.
struct SettingsNotificationsSection: View {
    let viewModel: SettingsViewModel
    let push: PushNotificationService
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "Notifications") {
                if push.authorizationStatus == .denied {
                    SettingsRow(title: "Notifications are off", subtitle: "Allow them in iOS Settings to get alerts.") {
                        SettingsChevron()
                    } action: {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    SettingsDivider()
                }
                if viewModel.notificationSettings != nil {
                    switchRow("Comments and replies", "Including your own threads", \.comments)
                    SettingsDivider()
                    switchRow("Personal bests", "When you or a friend beats one", \.personalBests)
                    SettingsDivider()
                    switchRow("Club activity", "New posts from \(viewModel.clubName ?? "your club")", \.clubActivity)
                    SettingsDivider()
                    switchRow("New workouts", "When your coach sets you a workout", \.newWorkouts)
                    SettingsDivider()
                    switchRow("Practice reminders", "Two hours before a practice you’re going to", \.practiceReminders)
                    SettingsDivider()
                    switchRow("Rank changes", "Mondays, when your place in last week’s metres moved", \.rankChanges)
                } else {
                    SettingsRowContent(title: "Notifications", subtitle: "Loading…") { ProgressView() }
                }
            }
            if let error = viewModel.notificationError {
                Text(error)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.System.error)
                    .padding(.top, 6)
            }
        }
    }

    /// A switch bound to one of the saved settings; turning it saves straight away.
    private func switchRow(
        _ title: String, _ subtitle: String, _ keyPath: WritableKeyPath<NotificationSettings, Bool>
    ) -> SettingsSwitchRow {
        SettingsSwitchRow(title: title, subtitle: subtitle, isOn: Binding(
            get: { viewModel.notificationSettings?[keyPath: keyPath] ?? false },
            set: { value in Task { await viewModel.updateNotifications { $0[keyPath: keyPath] = value } } }
        ))
    }
}
