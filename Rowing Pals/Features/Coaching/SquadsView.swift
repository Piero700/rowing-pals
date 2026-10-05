//
//  SquadsView.swift
//  Rowing Pals
//

import SwiftUI

/// The club's squads (CoachSquads, decision 39): each with how many rowers and who, opening to
/// edit; a note on what squads are for; New squad. For coaches (from Coaching) and the owner and
/// co-owners (from Manage club); the database refuses anyone else's changes.
struct SquadsView: View {
    @State private var viewModel = SquadsViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.squads.isEmpty {
                    if !viewModel.isLoading {
                        Text("No squads yet.")
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Tokens.Spacing.card)
                            .background(Self.cardShape.fill(Tokens.Surface.card))
                            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.squads.enumerated()), id: \.element.id) { index, squad in
                            HStack(spacing: Tokens.Spacing.loose) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(squad.name)
                                        .textStyle(Typography.rowTitle)
                                        .foregroundStyle(Tokens.Ink.primary)
                                    Text(viewModel.summary(squad))
                                        .textStyle(Typography.meta)
                                        .tabularNumerals()
                                        .foregroundStyle(Tokens.Ink.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .textStyle(Typography.pill)
                                    .foregroundStyle(Tokens.Ink.secondary)
                            }
                            .padding(.horizontal, Tokens.Spacing.card)
                            .padding(.vertical, Tokens.Spacing.loose)
                            .frame(minHeight: Tokens.Size.row)
                            .asButton { navigate(.squadEdit(squad.id)) }
                            .accessibilityElement(children: .combine)
                            if index < viewModel.squads.count - 1 {
                                Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                            }
                        }
                    }
                    .background(Self.cardShape.fill(Tokens.Surface.card))
                    .clipShape(Self.cardShape)
                    .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                }

                Text("Rowers can be in more than one squad. Squads are filters and workout targets: coaches still see every rower in the club.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, Tokens.Spacing.tight)
                    .fixedSize(horizontal: false, vertical: true)

                Button("New squad") { navigate(.squadEdit(nil)) }
                    .buttonStyle(.rpGlass)
                    .padding(.top, Tokens.Spacing.group)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Squads") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        // Reloads on returning from editing a squad.
        .onAppear { Task { await viewModel.load() } }
        .refreshable { await viewModel.load() }
    }
}
