//
//  TermsOfServiceView.swift
//  Rowing Pals
//

import SwiftUI

/// Lives in DesignSystem, not Features/Onboarding or Features/Settings —
/// both features present it, and "no feature imports another feature"
/// (CLAUDE.md) means a screen two features share can't live inside either.
///
/// Shown two ways: as a required read-and-agree step during sign-up (pass
/// `onAgree`, which shows an "I Agree" button instead of a Close button),
/// and as a plain, reopenable read from Settings (task 18) with no action
/// to take. Either way it's the same document — App Store Guideline 1.2
/// requires it, with the zero-tolerance clause below agreed at signup.
struct TermsOfServiceView: View {
    var onAgree: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Zero tolerance for abusive content and conduct") {
                        "Rowing Pals has zero tolerance for objectionable content or abusive " +
                        "behaviour of any kind — harassment, hate speech, nudity or sexual " +
                        "content, and anything illegal. Every photo you post is screened before " +
                        "it becomes visible, and every caption and comment is checked against a " +
                        "filter, but you're responsible for what you post regardless. Content or " +
                        "accounts reported by other users are reviewed, and a violation results " +
                        "in the content being removed and the account being blocked or deleted, " +
                        "at our discretion, without notice."
                    }
                    section("Reporting and blocking") {
                        "Every post and comment has a Report control. Reporting sends it for " +
                        "review; it does not remove it immediately. You can also block another " +
                        "user from their post — once blocked, neither of you can see the " +
                        "other's posts."
                    }
                    section("Your content") {
                        "You keep ownership of the photos and captions you post. By posting, " +
                        "you give Rowing Pals permission to store and display them to other " +
                        "users of the app, for as long as your account exists."
                    }
                    section("Your data") {
                        "Your training data — session times, splits, rates and distances — is " +
                        "visible to other users according to the visibility features of the app " +
                        "(feed, leaderboards, your profile). Deleting your account deletes this " +
                        "data. See Settings for account deletion."
                    }
                    section("Account standing") {
                        "We can suspend or terminate an account that violates these terms, " +
                        "including the zero-tolerance clause above, at our discretion."
                    }
                    section("Contact") {
                        "Questions or reports outside the in-app tools: use the support email " +
                        "link in Settings."
                    }
                }
                .padding(20)
            }
            .background(Tokens.Base.ground)
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onAgree {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("I Agree") {
                            onAgree()
                            dismiss()
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(Tokens.Accent.signal)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }

    private func section(_ title: String, _ body: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Tokens.Ink.primary)
            Text(body())
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }
}

#Preview {
    TermsOfServiceView()
}
