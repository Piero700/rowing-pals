//
//  FeedAnnouncementCard.swift
//  Rowing Pals
//

import SwiftUI

/// One announcement on the Feed (RowerFeedAnnouncement; decision 75): just its heading and who
/// posted it when, until tapped; then the message and when it comes off the Feed. Tapping again
/// folds it away. Coaches, the owner and co-owners also get Edit.
struct FeedAnnouncementCard: View {
    let announcement: Announcement
    let meta: String
    let isExpanded: Bool
    let canEdit: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.panel, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: Tokens.Spacing.loose) {
                    Image(systemName: "megaphone")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Accent.brand)
                        .frame(width: Tokens.Size.rowIcon, height: Tokens.Size.rowIcon)
                        .background(RoundedRectangle(cornerRadius: Tokens.Schedule.iconTileRadius, style: .continuous).fill(Tokens.Accent.brandSoft))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(announcement.heading)
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                            .multilineTextAlignment(.leading)
                        Text(meta)
                            .textStyle(Typography.statLabel)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .textStyle(Typography.pill)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())
            .accessibilityHint(isExpanded ? "Folds the message away" : "Shows the message")

            if isExpanded {
                if let message = announcement.message {
                    Text(message)
                        .textStyle(Typography.body)
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(.top, Tokens.Spacing.loose)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Text("On the Feed until \(AnnouncementRules.momentText(announcement.expiresAt, calendar: .current))")
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                    Spacer(minLength: Tokens.Spacing.tight)
                    if canEdit {
                        Button("Edit", action: onEdit)
                            .buttonStyle(.rpText)
                    }
                }
                .padding(.top, Tokens.Spacing.tight)
            }
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }
}
