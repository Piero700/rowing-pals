//
//  PrivacyPolicyView.swift
//  Rowing Pals
//

import SwiftUI

/// Settings → Help → Privacy Policy (decision 36). Lives beside `TermsOfServiceView` for the
/// same reason: a document more than one feature may show. It describes what the app actually
/// collects and who sees it; keep it in step when that changes (coaches read their club's
/// rowers since decision 35). The App Store also needs it at a public web address before submission.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("What we collect") {
                        "Your account: email address, password (stored only as a secure hash by " +
                        "our sign-in provider), display name, gender, level, club, whether you " +
                        "row or only coach, whether your club has made you a coach, your squads, " +
                        "your weekly target and profile picture. Your training: the sessions you post — distances, times, " +
                        "splits, stroke rates, training zone, effort rating, captions — the " +
                        "monitor photos, selfies and extra photos you attach, your test results, " +
                        "comments and reactions. If you add them, your date of birth and " +
                        "bodyweight. If you allow notifications, your phone's notification address."
                    }
                    section("What happens on your phone") {
                        "Reading the numbers off a monitor photo and checking photos for unsuitable " +
                        "content both happen on your iPhone. Photos are not sent anywhere to be " +
                        "read or checked."
                    }
                    section("Who can see it") {
                        "Your posts, photos and results are seen by people you allow under the " +
                        "app's visibility rules: people who follow you and members of your club, " +
                        "narrowed by each post's own setting and by a private account. Your " +
                        "club's coaches see all your training in that club — sessions, photos, " +
                        "tests, personal bests, effort ratings and predictions — even if your " +
                        "account is private, plus your age and bodyweight; you are told before " +
                        "you join a club that has coaches. Coaches can read but cannot comment or " +
                        "react unless the rules above already let them see the post. Nobody else " +
                        "sees your date of birth or bodyweight; they are also used to work out " +
                        "your predictions. We do not sell your data or show advertising."
                    }
                    section("Where it's kept") {
                        "Everything you post is stored with our database and file-storage " +
                        "provider, Supabase, and protected so that only the people above can " +
                        "read it. Notifications are delivered through Apple's push service."
                    }
                    section("Deleting your data") {
                        "Settings → Delete account permanently removes your account and " +
                        "everything you've posted: sessions, photos, results, comments and " +
                        "reactions."
                    }
                    section("Contact") {
                        "Questions about your data, or a request to see or correct it: use the " +
                        "support email link in Settings."
                    }
                }
                .padding(20)
            }
            .background(Tokens.Base.ground)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, _ body: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .textStyle(Typography.rowTitle)
                .foregroundStyle(Tokens.Ink.primary)
            Text(body())
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
