//
//  YourBestsView.swift
//  Rowing Pals
//

import SwiftUI

/// Settings → Your bests (decision 64): the bests you typed in at sign-up, to change or add to
/// — your 2k and 5k, and any other distance or time. They give your predictions a starting
/// point; they're never a PB or on a leaderboard.
struct YourBestsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [BestRow] = BestRow.rows(from: [])
    @State private var saved: [DeclaredBest] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !isSaving && !isLoading && !rows.contains(where: \.blocksSaving)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(Self.explanation)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, Tokens.Spacing.loose)
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    BestsEditor(rows: $rows)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Your bests") { dismiss() } }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                .buttonStyle(.rpPrimary)
                .disabled(!canSave)
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.vertical, Tokens.Spacing.tight)
                .background(Tokens.Base.ground)
        }
        .background(Tokens.Base.ground)
        .dismissesKeyboardOnTap()
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    /// What these are for, on sign-up and here.
    static let explanation = "Your current bests give your 2k and 5k predictions a starting point before you've logged an all-out piece. Each counts for 30 days from when you enter it, fading as your own pieces come in. They're never shown as PBs or on a leaderboard."

    private func load() async {
        defer { isLoading = false }
        do {
            saved = try await DeclaredBestService.mine()
            rows = BestRow.rows(from: saved)
        } catch {
            errorMessage = "Couldn't load your bests: \(error.localizedDescription)"
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await DeclaredBestService.save(rows.compactMap(\.parsed), previous: saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
