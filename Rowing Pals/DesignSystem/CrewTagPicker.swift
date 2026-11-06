//
//  CrewTagPicker.swift
//  Rowing Pals
//

import SwiftUI

/// "Trained with" (decision 90): the poster's clubmates who row, with a search box; tap people to
/// tick them, then Done. Used when posting and when changing a post's tags afterwards.
struct CrewTagPicker: View {
    let people: [ClubMember]
    /// True while the clubmates load.
    var isLoading = false
    let onDone: (Set<UUID>) -> Void

    @State private var selected: Set<UUID>
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private static let rowShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(people: [ClubMember], selected: Set<UUID>, isLoading: Bool = false, onDone: @escaping (Set<UUID>) -> Void) {
        self.people = people
        self.isLoading = isLoading
        self.onDone = onDone
        _selected = State(initialValue: selected)
    }

    private var shown: [ClubMember] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return people }
        return people.filter { $0.displayName.localizedCaseInsensitiveContains(text) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.rpText)
                Spacer(minLength: 0)
                Text("Trained with")
                    .textStyle(Typography.selectedValue)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: 0)
                Button("Done") {
                    onDone(selected)
                    dismiss()
                }
                .buttonStyle(.rpText)
                .fontWeight(.semibold)
            }
            .padding(.top, Tokens.Spacing.group)

            HStack(spacing: Tokens.Spacing.tight) {
                RPIconView(icon: .search, size: Tokens.Icon.small)
                    .foregroundStyle(Tokens.Ink.secondary)
                TextField("Search your club", text: $query)
                    .textStyle(Typography.body)
                    .foregroundStyle(Tokens.Ink.primary)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .frame(height: Tokens.Size.input)
            .glassSurface(cornerRadius: Tokens.Radius.input)
            .padding(.top, Tokens.Spacing.loose)

            Text(selected.isEmpty ? "Tag the clubmates you trained with. The post says “with …”."
                 : "\(selected.count) tagged")
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.tight)

            ScrollView {
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(Tokens.Spacing.card)
                    } else if people.isEmpty {
                        Text("Nobody to tag yet: your clubmates who row appear here.")
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Tokens.Spacing.card)
                    } else if shown.isEmpty {
                        Text("Nobody in your club by that name.")
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Tokens.Spacing.card)
                    }
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, person in
                        if index > 0 { Rectangle().fill(Tokens.Surface.line).frame(height: Tokens.Grouped.hairline) }
                        row(person)
                    }
                }
                .background(Self.rowShape.fill(Tokens.Surface.card))
                .clipShape(Self.rowShape)
                .overlay { Self.rowShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
                .padding(.top, Tokens.Spacing.loose)
                .padding(.bottom, Tokens.Spacing.group)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, Tokens.Spacing.screen)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Tokens.Base.ground)
    }

    private func row(_ person: ClubMember) -> some View {
        let isOn = selected.contains(person.id)
        return Button {
            if isOn { selected.remove(person.id) } else { selected.insert(person.id) }
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                AvatarPlaceholder(diameter: Tokens.Size.rowIcon, name: person.displayName, userId: person.id)
                Text(person.displayName)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle()
                        .strokeBorder(isOn ? Tokens.Accent.brand : Tokens.Ink.secondary, lineWidth: 1.5)
                    if isOn {
                        Circle().fill(Tokens.Accent.brand)
                        RPIconView(icon: .check, size: Tokens.Icon.badge, weight: Tokens.Icon.stroke(for: Tokens.Icon.small))
                            .foregroundStyle(Tokens.Ink.onBrand)
                    }
                }
                .frame(width: Tokens.Icon.large, height: Tokens.Icon.large)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .frame(minHeight: Tokens.Size.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(person.displayName)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
