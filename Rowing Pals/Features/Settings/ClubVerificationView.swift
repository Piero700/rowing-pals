//
//  ClubVerificationView.swift
//  Rowing Pals
//

import SwiftUI

/// Settings → Your club → Verification (decision 98): the owner applies for the verified tag, so
/// rowers joining can tell their club is the real one. The Rowing Pals team checks each
/// application by hand and approves it in the database; until then it reads "Waiting".
struct ClubVerificationView: View {
    let clubName: String
    /// Where the club stands; Settings passes what it loaded and gets the new state back.
    @Binding var status: ClubService.Verification

    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                statusCard

                if status == .none || status == .declined {
                    Text("A note for us (optional)")
                        .textStyle(Typography.fieldLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, Tokens.Spacing.tight)
                    TextField("Your club’s website, British Rowing code, or your role", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                        .textStyle(Typography.body)
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(14)
                        .background(Self.cardShape.fill(Tokens.Surface.card))
                        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
                        .onChange(of: message) { message = String(message.prefix(500)) }
                    Text("We check that the club is real and that you run it, then add the tag. It usually takes a few days.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .guidance()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.loose)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Verification") { dismiss() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if status == .none || status == .declined {
                Button(status == .declined ? "Apply again" : "Apply for verification") { Task { await apply() } }
                    .buttonStyle(.rpPrimary)
                    .disabled(isSending)
                    .padding(.horizontal, Tokens.Spacing.screen)
                    .padding(.top, Tokens.Spacing.loose)
                    .padding(.bottom, Tokens.Spacing.screen)
                    .background(Tokens.Base.ground)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Tokens.Base.ground)
        .dismissesKeyboardOnTap()
    }

    /// The club's name with its tag (or not) and where the application stands.
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ClubNameLabel(name: clubName, isVerified: status == .verified, badgeSize: Tokens.Icon.regular)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
            Text(statusTitle)
                .textStyle(Typography.rowTitle)
                .foregroundStyle(status == .verified ? Tokens.Accent.success : Tokens.Ink.primary)
            Text(statusDetail)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private var statusTitle: String {
        switch status {
        case .none: "Not verified"
        case .pending: "Waiting to be checked"
        case .declined: "Not approved"
        case .verified: "Verified"
        }
    }

    private var statusDetail: String {
        switch status {
        case .none: "Verified clubs show a tag beside their name everywhere it appears, so people joining know it’s the real club."
        case .pending: "We’ve got your application. The tag appears by itself once it’s approved."
        case .declined: "We couldn’t confirm the club this time. You can add more detail and apply again."
        case .verified: "The tag shows beside \(clubName) in search, on the club and on every member’s profile."
        }
    }

    private func apply() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await ClubService.applyForVerification(message: message)
            status = .pending
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
