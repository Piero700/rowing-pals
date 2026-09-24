//
//  PeopleListView.swift
//  Rowing Pals
//

import SwiftUI

/// Followers, Following and Find rowers — one flat list of rows: avatar,
/// name + club/level, and a follow button unless the row is you
/// (docs/design/rowing-pals-redesign-handoff-v2.md §2 Screen 09). Tapping a
/// row opens that rower's profile.
struct PeopleListView: View {
    @State private var viewModel: PeopleListViewModel
    @State private var query = ""
    @Environment(\.navigate) private var navigate

    init(kind: PeopleListKind) {
        _viewModel = State(initialValue: PeopleListViewModel(kind: kind))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isSearchable {
                    searchField
                }

                if let message = viewModel.errorMessage {
                    Text(message)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.System.error)
                }

                if viewModel.people.isEmpty && !viewModel.isLoading {
                    Text(viewModel.emptyMessage)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.people) { person in
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
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        // Reloads as the search text changes; the cancelled previous task
        // gives a light debounce.
        .task(id: query) {
            if viewModel.isSearchable {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            await viewModel.load(query: query)
        }
        .refreshable { await viewModel.load(query: query) }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.Ink.secondary)
            TextField("Search rowers", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.07))
        }
    }

    private func row(_ person: PersonSummary) -> some View {
        HStack(spacing: 12) {
            Button {
                navigate(.profile(person.id))
            } label: {
                HStack(spacing: 12) {
                    AvatarPlaceholder(diameter: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(person.displayName)
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundStyle(Tokens.Ink.primary)
                                .lineLimit(1)
                            if person.isPrivate {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Tokens.Ink.secondary)
                                    .accessibilityLabel("Private account")
                            }
                        }
                        Text(subtitle(for: person))
                            .textStyle(Typography.bodySecondary)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if person.id != viewModel.viewerId {
                FollowButton(
                    state: viewModel.state(for: person.id),
                    isBusy: viewModel.busyIds.contains(person.id),
                    compact: true
                ) {
                    Task { await viewModel.toggleFollow(person.id) }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.06))
        }
    }

    private func subtitle(for person: PersonSummary) -> String {
        let level = person.category.rawValue.capitalized
        if let club = person.club?.name {
            return "\(club) · \(level)"
        }
        return level
    }
}
