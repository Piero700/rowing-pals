//
//  AnswerListCard.swift
//  Rowing Pals
//

import SwiftUI

/// One group of a session's or race's answers (CoachAvailability, CoachRace): a title with its
/// count, then each rower with their side or reason. Long lists show the first eight and
/// "and N more", which opens the rest.
struct AnswerListCard: View {
    struct Person: Identifiable, Equatable {
        let member: ClubMember
        /// The side they row on, or their reason in quotes; nil for neither.
        let detail: String?
        var id: UUID { member.id }
    }

    let title: String
    let people: [Person]
    var onOpen: ((UUID) -> Void)? = nil

    @State private var isShowingAll = false

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let shownAtFirst = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .textStyle(Typography.sectionTitle)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Text("\(people.count)")
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.sectionTop)
            .padding(.bottom, Tokens.Spacing.tight)

            if people.isEmpty {
                Text("Nobody.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, person in
                        if index > 0 {
                            Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                        }
                        personRow(person)
                    }
                    if hidden > 0 {
                        Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                        Button("and \(hidden) more") { isShowingAll = true }
                            .buttonStyle(.rpText)
                            .tabularNumerals()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Tokens.Spacing.card)
                            .frame(minHeight: Tokens.Size.rowCompact)
                    }
                }
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .clipShape(Self.cardShape)
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            }
        }
    }

    private var shown: [Person] {
        isShowingAll ? people : Array(people.prefix(Self.shownAtFirst))
    }

    private var hidden: Int { people.count - shown.count }

    @ViewBuilder
    private func personRow(_ person: Person) -> some View {
        let row = HStack(spacing: Tokens.Spacing.loose) {
            AvatarPlaceholder(diameter: Tokens.Size.rowIcon, name: person.member.displayName, userId: person.member.id)
            Text(person.member.displayName)
                .textStyle(Typography.rowTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let detail = person.detail {
                Text(detail)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .frame(minHeight: Tokens.Size.rowCompact)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        if let onOpen {
            row.asButton { onOpen(person.member.id) }
        } else {
            row
        }
    }
}
