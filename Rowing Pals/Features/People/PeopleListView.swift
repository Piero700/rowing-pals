//
//  PeopleListView.swift
//  Rowing Pals
//

import SwiftUI

/// Find rowers, Followers and Following, to v3 §09 (`docs/design/v3/RP Screen.dc.html`):
/// glass back header, then — for Find rowers — "Search your rowing community" and a 52 pt
/// search field; then one card of rows: 38 pt avatar, name, club, and a glass
/// Follow / Following / Requested / Follow back pill unless the row is you. v3 draws only
/// Find rowers; the two follow lists use the same layout so all three match. Tapping a row
/// opens that rower's profile; a private rower keeps phase E's lock icon.
struct PeopleListView: View {
    @State private var viewModel: PeopleListViewModel
    @State private var query = ""
    @Environment(\.navigate) private var navigate
    @Environment(\.dismiss) private var dismiss

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(kind: PeopleListKind) {
        _viewModel = State(initialValue: PeopleListViewModel(kind: kind))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isSearchable {
                    Text("Search your rowing community")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 12)
                    searchField
                        .padding(.bottom, 14)
                }

                if let message = viewModel.errorMessage {
                    Text(message)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.bottom, 12)
                }

                if viewModel.people.isEmpty && !viewModel.isLoading {
                    Text(viewModel.emptyMessage)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if !viewModel.people.isEmpty {
                    list
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: viewModel.title) { dismiss() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Tokens.Base.ground)
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

    /// 52 pt, card fill, 1 pt line, radius 24; a 20 pt search icon inset 14.
    private var searchField: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 20, height: 20)
                .foregroundStyle(Tokens.Ink.secondary)
                .accessibilityHidden(true)
            TextField("Search rowers", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Tokens.Size.input)
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
    }

    /// One card (radius 30, card fill, card edge), rows split by 1 pt lines.
    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.people.enumerated()), id: \.element.id) { index, person in
                row(person)
                if index < viewModel.people.count - 1 {
                    Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                }
            }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .clipShape(Self.cardShape)
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func row(_ person: PersonSummary) -> some View {
        HStack(spacing: Tokens.Spacing.gap) {
            HStack(spacing: Tokens.Spacing.gap) {
                AvatarPlaceholder(diameter: 38, name: person.displayName, userId: person.id)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(person.displayName)
                            .textStyle(Typography.name)
                            .foregroundStyle(Tokens.Ink.primary)
                            .lineLimit(1)
                        if person.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Tokens.Ink.secondary)
                                .accessibilityLabel("Private account")
                        }
                    }
                    Text(person.club?.name ?? "No club")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .asButton { navigate(.profile(person.id)) }
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens their profile")

            if person.id != viewModel.viewerId {
                FollowButton(
                    state: viewModel.state(for: person.id),
                    followsYou: viewModel.followsViewer.contains(person.id),
                    isBusy: viewModel.busyIds.contains(person.id),
                    variant: .row
                ) {
                    Task { await viewModel.toggleFollow(person.id) }
                }
            }
        }
        .padding(12)
    }
}
