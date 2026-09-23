//
//  FollowRequestsView.swift
//  Rowing Pals
//

import SwiftUI

/// Pending follow requests on your own (private) account, each with
/// Accept and Decline. Opened from "Follow requests · N" on the profile
/// (docs/design/rowing-pals-redesign-handoff-v2.md §2 Screen 06, §3).
struct FollowRequestsView: View {
    @State private var viewModel = FollowRequestsViewModel()
    @Environment(\.navigate) private var navigate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.System.error)
                }

                if viewModel.requests.isEmpty && !viewModel.isLoading {
                    Text("No pending requests.")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.requests) { person in
                            row(person)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Tokens.Base.ground)
        .navigationTitle("Follow requests")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func row(_ person: PersonSummary) -> some View {
        HStack(spacing: 12) {
            Button {
                navigate(.profile(person.id))
            } label: {
                HStack(spacing: 12) {
                    AvatarPlaceholder(diameter: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.displayName)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(Tokens.Ink.primary)
                            .lineLimit(1)
                        Text(person.club?.name ?? person.category.rawValue.capitalized)
                            .textStyle(Typography.bodySecondary)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            let isBusy = viewModel.busyIds.contains(person.id)
            Button {
                Task { await viewModel.decline(person.id) }
            } label: {
                Text("Decline")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().fill(Tokens.Ink.primary.opacity(0.16))
                    }
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            Button {
                Task { await viewModel.accept(person.id) }
            } label: {
                Text("Accept")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Tokens.Base.dark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background { Capsule().fill(Tokens.Accent.brand) }
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        }
        .padding(12)
        .opacity(viewModel.busyIds.contains(person.id) ? 0.6 : 1)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.06))
        }
    }
}

@Observable
final class FollowRequestsViewModel {
    var requests: [PersonSummary] = []
    var busyIds: Set<UUID> = []
    var isLoading = false
    var errorMessage: String?

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            requests = try await FollowService.pendingRequests()
            errorMessage = nil
        } catch {
            print("Follow requests load failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func accept(_ id: UUID) async {
        await act(on: id) { try await FollowService.accept(follower: id) }
    }

    @MainActor
    func decline(_ id: UUID) async {
        await act(on: id) { try await FollowService.decline(follower: id) }
    }

    private func act(on id: UUID, _ work: () async throws -> Void) async {
        guard !busyIds.contains(id) else { return }
        busyIds.insert(id)
        defer { busyIds.remove(id) }
        do {
            try await work()
            requests.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
