//
//  ClubVerificationsView.swift
//  Rowing Pals
//

import SwiftUI

/// Settings → Club verifications (decision 108), for app admins only: clubs asking for the verified
/// tag, waiting first, then the ones already decided. Check the club is real and the person asking
/// runs it before approving; every decision can be undone here.
struct ClubVerificationsView: View {
    @State private var viewModel = ClubVerificationsViewModel()
    /// A verified tag about to be taken away: asked to confirm first.
    @State private var removing: ClubVerificationRequest?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Grouped.groupGap) {
                if let error = viewModel.errorMessage {
                    GroupedError(text: error)
                }
                if viewModel.hasLoaded && viewModel.requests.isEmpty && viewModel.errorMessage == nil {
                    GuidedText("No clubs have asked to be verified yet.",
                               hint: "When a club owner applies under Settings → Your club → Verification, it shows here.")
                        .padding(.top, Tokens.Spacing.group)
                }
                if !viewModel.waiting.isEmpty {
                    sectionTitle("Waiting · \(viewModel.waiting.count)")
                    ForEach(viewModel.waiting) { request in
                        card(request)
                    }
                }
                if !viewModel.decided.isEmpty {
                    sectionTitle("Decided")
                    ForEach(viewModel.decided) { request in
                        card(request)
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.loose)
            .padding(.bottom, Tokens.Spacing.group)
        }
        .overlay {
            if viewModel.isLoading && !viewModel.hasLoaded { ProgressView() }
        }
        .background(Tokens.Base.ground)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Club verifications") { dismiss() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert("Remove the verified tag?", isPresented: Binding(
            get: { removing != nil },
            set: { if !$0 { removing = nil } }
        )) {
            Button("Cancel", role: .cancel) { removing = nil }
            Button("Remove", role: .destructive) {
                guard let request = removing else { return }
                removing = nil
                Task { await viewModel.decide(request, .remove) }
            }
        } message: {
            Text("\(removing?.clubName ?? "The club") loses the tag beside its name. You can approve it again later.")
        }
    }

    private func card(_ request: ClubVerificationRequest) -> ClubVerificationCard {
        ClubVerificationCard(request: request, isDeciding: viewModel.decidingClub == request.clubId) { decision in
            if decision == .remove {
                removing = request
            } else {
                Task { await viewModel.decide(request, decision) }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, Tokens.Grouped.rowPadding)
            .accessibilityAddTraits(.isHeader)
    }
}
