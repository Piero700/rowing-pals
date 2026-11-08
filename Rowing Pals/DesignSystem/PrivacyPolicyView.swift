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
                        "Your account: email address, password (if you use one, stored only as a " +
                        "secure hash by our sign-in provider) or your Apple or Google sign-in, " +
                        "username, display name, gender, level, club, whether you row or only coach, " +
                        "whether your club has made you a coach, your squads, your weekly target and " +
                        "profile picture. Your training: the sessions you post — distances, times, " +
                        "splits, stroke rates, training zone, effort rating, captions — the monitor " +
                        "photos, selfies and extra photos you attach, your test results, comments and " +
                        "reactions. Your activity: who you follow and block, and what you report. " +
                        "Your club: your answers to practices, your attendance, your seat in a boat, " +
                        "and any note a club owner sends with a verification request. From your " +
                        "coaches: the scores they write for you on a workout's notepad. If you add " +
                        "them, your date of birth and bodyweight. If you allow notifications, your " +
                        "phone's notification address."
                    }
                    section("What happens on your phone") {
                        "Reading the numbers off a monitor photo happens on your iPhone, and the " +
                        "photo is not sent anywhere to be read. When a coach scans a monitor onto a " +
                        "notepad, the photo is read on the phone and thrown away; only the numbers " +
                        "are kept. The photos you post are uploaded with your post."
                    }
                    section("Who can see it") {
                        "Your posts and their photos are seen by people you allow under the app's " +
                        "visibility rules: friends (people you follow who follow you back) and " +
                        "members of your club, narrowed by each post's own setting and by a private " +
                        "account. Your username, display name, club, level and gender can be seen by " +
                        "any Rowing Pals user. Your profile picture, test results, training totals " +
                        "and leaderboard places can also be seen by any Rowing Pals user, unless your " +
                        "account is private; then only people you've approved and your club's coaches " +
                        "can see them. Your club's coaches see all your training in that club — " +
                        "sessions, photos, tests, personal bests, effort ratings and predictions — " +
                        "even if your account is private, plus your age and bodyweight; you are told " +
                        "before you join a club that has coaches. Scores your coaches write for you " +
                        "are seen by your club's coaches and by you. Coaches can read but cannot " +
                        "comment or react unless the rules above already let them see the post. " +
                        "Nobody else sees your date of birth or bodyweight; they are also used to " +
                        "work out your predictions. We do not sell your data or show advertising."
                    }
                    section("Where it's kept") {
                        "Everything you post is stored with our database and file-storage provider, " +
                        "Supabase, and protected so that only the people above can read it. " +
                        "Notifications are delivered through Apple's push service. If you sign in " +
                        "with Apple or Google, they confirm who you are. We keep your data until you " +
                        "delete it or your account, or until we remove it under our Terms of Service."
                    }
                    section("Deleting your data") {
                        "Settings → Delete account permanently removes your account and everything " +
                        "you've posted: sessions, photos, results, comments and reactions. The scores " +
                        "your coaches wrote for you go too. Anything a coach typed into a notepad's " +
                        "notes or tables stays with your club, because it isn't linked to your " +
                        "account."
                    }
                    section("Contact") {
                        "Questions about your data, or a request to see or correct it: use the " +
                        "support email link in Settings or email support@rowingpals.com."
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
