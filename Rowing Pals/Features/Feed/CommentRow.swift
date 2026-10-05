//
//  CommentRow.swift
//  Rowing Pals
//

import SwiftUI

/// One comment: author picture, name, when, and the text, on a soft bubble. Press and hold
/// to report someone else's comment (task 17). Used inline on the workout and in the thread.
struct CommentRow: View {
    let comment: CommentThread.Entry
    let canReport: Bool
    let onReport: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.gap) {
            AvatarPlaceholder(diameter: Tokens.Size.commentAvatar, name: comment.authorName, userId: comment.authorId)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    Text(comment.authorName)
                        .textStyle(Typography.commentAuthor)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(comment.createdAt.postedAgoLabel)
                        .textStyle(Typography.commentTime)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary.opacity(0.8))
                }
                Text(comment.body)
                    .textStyle(Typography.commentBody)
                    .foregroundStyle(Tokens.Ink.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.comment, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.05))
        }
        .contextMenu {
            if canReport {
                Button(action: onReport) {
                    Label("Report comment", systemImage: "flag")
                }
            }
        }
    }
}
