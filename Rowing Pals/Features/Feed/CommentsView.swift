//
//  CommentsView.swift
//  Rowing Pals
//

import SwiftUI

/// The full-screen comments thread (handoff §2 `comments`; v3 prototype `openComments`): a
/// back header titled "Comments", whose post it is, every comment oldest first, and the
/// composer pinned to the bottom. Opened from a feed card's comments pill, or from "View all"
/// on the workout screen, where it shares that screen's `CommentThread`.
struct CommentsView: View {
    @State private var thread: CommentThread
    /// "Joe Bloggs · UT2" — whose post, and what it was.
    let subtitle: String
    /// Called with the new total whenever it changes, so the screen underneath can update.
    var onCountChange: (Int) -> Void = { _ in }
    /// A thread made here is loaded and closed here; a shared one belongs to its owner.
    private let ownsThread: Bool

    @State private var draft = ""
    @State private var commentBeingReported: UUID?
    @State private var isShowingReportConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private static let reportReasons = ["Inappropriate content", "Spam", "Harassment", "Other"]
    private static let bottomID = "bottom"

    /// From the feed: a thread of its own.
    init(sessionId: UUID, subtitle: String, onCountChange: @escaping (Int) -> Void = { _ in }) {
        _thread = State(initialValue: CommentThread(sessionId: sessionId))
        self.subtitle = subtitle
        self.onCountChange = onCountChange
        ownsThread = true
    }

    /// From the workout screen: the same thread its inline comments show.
    init(thread: CommentThread, subtitle: String) {
        _thread = State(initialValue: thread)
        self.subtitle = subtitle
        ownsThread = false
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Spacing.gap) {
                    Text(subtitle)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.bottom, 4)

                    content

                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.bottom, Tokens.Spacing.loose)
            }
            .scrollIndicators(.hidden)
            // A short thread starts at the top, as in v3; a long one opens on its newest
            // comments and stays there as new ones arrive.
            .defaultScrollAnchor(.top, for: .alignment)
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .onChange(of: thread.comments.count) { _, count in
                onCountChange(count)
                withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Comments") { dismiss() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                if let errorMessage = thread.errorMessage {
                    Text(errorMessage)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
                }
                CommentComposer(draft: $draft) { text in
                    Task { await thread.postComment(body: text) }
                }
            }
        }
        .background(Tokens.Base.ground)
        .dismissesKeyboardOnTap()
        .edgeSwipeToDismiss()
        .task {
            if ownsThread { await thread.load() }
        }
        .onDisappear {
            if ownsThread { thread.stop() }
        }
        .confirmationDialog(
            "Why are you reporting this comment?",
            isPresented: Binding(
                get: { commentBeingReported != nil },
                set: { if !$0 { commentBeingReported = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(Self.reportReasons, id: \.self) { reason in
                Button(reason) {
                    guard let commentId = commentBeingReported else { return }
                    Task {
                        if await thread.reportComment(commentId, reason: reason) {
                            isShowingReportConfirmation = true
                        }
                    }
                }
            }
        }
        .alert("Report sent", isPresented: $isShowingReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks — we've received your report and will review it.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if thread.comments.isEmpty {
            if thread.isLoading || (!thread.hasLoaded && thread.errorMessage == nil) {
                ProgressView()
                    .tint(Tokens.Ink.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if thread.hasLoaded {
                Text("No comments yet. Say something to start the conversation.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        ForEach(thread.comments) { comment in
            CommentRow(comment: comment, canReport: !thread.isOwnComment(comment)) {
                commentBeingReported = comment.id
            }
        }
    }
}
