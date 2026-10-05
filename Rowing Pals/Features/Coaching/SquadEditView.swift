//
//  SquadEditView.swift
//  Rowing Pals
//

import SwiftUI

/// One squad, or a new one (CoachSquadEdit, decision 39): its name, its members chosen from the
/// club's rowers with Select all, Save squad and Delete squad.
struct SquadEditView: View {
    /// nil for a new squad.
    let squadId: UUID?

    @State private var viewModel = SquadsViewModel()
    @State private var name = ""
    @State private var memberIds: Set<UUID> = []
    @State private var hasLoaded = false
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let fieldShape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                title("Name")
                    .padding(.top, Tokens.Spacing.tight)
                TextField("Squad name", text: $name)
                    .textStyle(Typography.bodyV3)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, Tokens.Spacing.card)
                    .frame(minHeight: Tokens.Size.input)
                    .background(Self.fieldShape.fill(Tokens.Surface.card))
                    .overlay { Self.fieldShape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }

                HStack(alignment: .firstTextBaseline) {
                    title("Members · \(memberIds.count) selected")
                    Spacer(minLength: 0)
                    Button(allSelected ? "Select none" : "Select all") {
                        memberIds = allSelected ? [] : Set(viewModel.rowers.map(\.id))
                    }
                    .buttonStyle(.rpText)
                    .disabled(viewModel.rowers.isEmpty)
                }
                .padding(.top, Tokens.Spacing.group)

                membersCard

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }

                Button {
                    Task {
                        if await viewModel.save(id: squadId, name: name, memberIds: memberIds) { dismiss() }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(Tokens.Ink.onBrand)
                    } else {
                        Text("Save squad")
                    }
                }
                .buttonStyle(.rpPrimary)
                .disabled(viewModel.isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.top, Tokens.Spacing.group)

                if squadId != nil {
                    Button("Delete squad") { isConfirmingDelete = true }
                        .buttonStyle(.rpDestructive)
                        .disabled(viewModel.isSaving)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: squadId == nil ? "New squad" : "Edit squad") { dismiss() }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task {
            await viewModel.load()
            guard !hasLoaded else { return }
            hasLoaded = true
            if let squadId, let squad = viewModel.squads.first(where: { $0.id == squadId }) {
                name = squad.name
                memberIds = squad.memberIds
            }
        }
        .alert("Delete \(name.isEmpty ? "this squad" : name)?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                guard let squadId else { return }
                Task { if await viewModel.delete(squadId) { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its rowers stay in the club and in any other squads.")
        }
    }

    private var allSelected: Bool {
        !viewModel.rowers.isEmpty && viewModel.rowers.allSatisfy { memberIds.contains($0.id) }
    }

    @ViewBuilder
    private var membersCard: some View {
        if viewModel.rowers.isEmpty {
            Text(viewModel.isLoading ? "Loading…" : "Nobody who rows is in the club yet.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Tokens.Spacing.card)
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.rowers.enumerated()), id: \.element.id) { index, person in
                    let isOn = memberIds.contains(person.id)
                    HStack(spacing: Tokens.Spacing.loose) {
                        AvatarPlaceholder(diameter: Tokens.Size.rowerCardAvatar, name: person.displayName, userId: person.id)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName)
                                .textStyle(Typography.rowTitle)
                                .foregroundStyle(Tokens.Ink.primary)
                            Text(person.category.rawValue.capitalized)
                                .textStyle(Typography.meta)
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        ZStack {
                            if isOn {
                                Circle().fill(Tokens.Accent.brand)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Tokens.Ink.onBrand)
                            } else {
                                Circle().strokeBorder(Tokens.Surface.line, lineWidth: 1.5)
                            }
                        }
                        .frame(width: Tokens.Size.checkbox, height: Tokens.Size.checkbox)
                    }
                    .padding(.horizontal, Tokens.Spacing.card)
                    .padding(.vertical, Tokens.Spacing.loose)
                    .frame(minHeight: Tokens.Size.rowCompact)
                    .asButton {
                        if isOn { memberIds.remove(person.id) } else { memberIds.insert(person.id) }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    if index < viewModel.rowers.count - 1 {
                        Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                    }
                }
            }
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .clipShape(Self.cardShape)
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, Tokens.Spacing.tight)
            .accessibilityAddTraits(.isHeader)
    }
}
