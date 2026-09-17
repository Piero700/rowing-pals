//
//  PostDetailView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 8 — one post, opened. Full segment breakdown, the gold
/// test-result banner when it applies, reactions and a comment thread —
/// both live via Realtime (task 16).
struct PostDetailView: View {
    @State private var viewModel: PostDetailViewModel
    @State private var isSelfiePrimary = false
    @State private var commentDraft = ""
    @State private var isShowingMoreReactions = false
    @State private var isShowingReportReasons = false
    @State private var isShowingReportConfirmation = false
    @State private var isShowingBlockConfirmation = false
    @State private var commentBeingReported: UUID?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isComposerFocused: Bool
    /// Redesign phase B — per-device display preferences, not synced to
    /// the profile. See DesignSystem/DistanceUnit.swift, PaceDisplay.swift.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    private static let emoji: [String: String] = [
        "fire": "🔥", "grimace": "😬", "clap": "👏", "eyes": "👀",
        "muscle": "💪", "wow": "😮", "boat": "🚣"
    ]
    private static let reportReasons = ["Inappropriate content", "Spam", "Harassment", "Other"]

    init(sessionId: UUID) {
        _viewModel = State(initialValue: PostDetailViewModel(sessionId: sessionId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero

                VStack(alignment: .leading, spacing: 12) {
                    if let banner = viewModel.testBanner {
                        pbBanner(banner)
                    }
                    sessionTotalCard
                    if !viewModel.reactions.isEmpty {
                        reactionRow
                    }
                    commentThread
                }
                .padding(14)
                .padding(.bottom, 80)
            }
        }
        .background(Tokens.Base.ground)
        .dismissesKeyboardOnTap()
        .edgeSwipeToDismiss()
        .overlay(alignment: .bottom) {
            composer
        }
        .ignoresSafeArea(edges: .top)
        .task { await viewModel.load() }
        .onDisappear { viewModel.stop() }
        .confirmationDialog(
            commentBeingReported == nil ? "Why are you reporting this post?" : "Why are you reporting this comment?",
            isPresented: $isShowingReportReasons,
            titleVisibility: .visible
        ) {
            ForEach(Self.reportReasons, id: \.self) { reason in
                Button(reason) {
                    Task {
                        let sent: Bool
                        if let commentId = commentBeingReported {
                            sent = await viewModel.reportComment(commentId, reason: reason)
                        } else {
                            sent = await viewModel.reportPost(reason: reason)
                        }
                        if sent { isShowingReportConfirmation = true }
                    }
                }
            }
        }
        .alert("Report sent", isPresented: $isShowingReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks — we've received your report and will review it.")
        }
        .alert("Block \(viewModel.author?.displayName ?? "this rower")?", isPresented: $isShowingBlockConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                Task {
                    await viewModel.blockAuthor()
                    dismiss()
                }
            }
        } message: {
            Text("You won't see their posts, and they won't see yours.")
        }
    }

    private var primaryURL: URL? {
        let monitorURL = viewModel.segments.first?.monitorPhotoPath.flatMap { viewModel.monitorURLs[$0] }
        return isSelfiePrimary ? viewModel.selfieURL : monitorURL
    }

    private var insetURL: URL? {
        let monitorURL = viewModel.segments.first?.monitorPhotoPath.flatMap { viewModel.monitorURLs[$0] }
        return isSelfiePrimary ? monitorURL : viewModel.selfieURL
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            CachedAsyncImage(url: primaryURL) {
                PhotoPlaceholder(cornerRadius: 0, caption: "MONITOR PHOTO")
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: 330)
            .clipped()

            Button {
                withAnimation(.snappy) { isSelfiePrimary.toggle() }
            } label: {
                CachedAsyncImage(url: insetURL) {
                    PhotoPlaceholder(cornerRadius: 18, caption: "SELFIE")
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 86, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)
            .padding(.top, 70)

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(Color.black.opacity(0.28))
                        Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .padding(.leading, 14)
            .padding(.top, 54)

            if !viewModel.isOwnPost {
                moreOptionsButton
                    .padding(.trailing, 14)
                    .padding(.top, 54)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 9) {
                AvatarPlaceholder(diameter: 24, streakDays: viewModel.authorStreakDays)
                Text(viewModel.author?.displayName ?? "")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                if !viewModel.isOwnPost {
                    followButton
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule().fill(.ultraThinMaterial)
            }
            .padding(.top, 96)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 14)
        }
        .frame(height: 330)
        .clipped()
    }

    private var followButton: some View {
        Button {
            Task { await viewModel.toggleFollow() }
        } label: {
            Text(viewModel.isFollowingAuthor ? "Following" : "Follow")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(viewModel.isFollowingAuthor ? Tokens.Ink.primary : Tokens.Base.dark)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(viewModel.isFollowingAuthor ? Tokens.Ink.primary.opacity(0.16) : Tokens.Accent.brand)
                }
        }
        .buttonStyle(.plain)
    }

    /// App Store Guideline 1.2 — Reporting and Blocking, task 17. Hidden on
    /// the author's own post entirely: you can't report or block yourself.
    private var moreOptionsButton: some View {
        Menu {
            Button {
                commentBeingReported = nil
                isShowingReportReasons = true
            } label: {
                Label("Report post", systemImage: "flag")
            }
            Button(role: .destructive) {
                isShowingBlockConfirmation = true
            } label: {
                Label("Block \(viewModel.author?.displayName ?? "this rower")", systemImage: "hand.raised")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(Color.black.opacity(0.28))
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
        }
    }

    /// "2k test · 7:12.8 · Personal best · 3rd overall, 1st novice women" —
    /// design brief, Screen 8. Only the parts that actually apply render:
    /// no "Personal best" clause if it wasn't, no rank clause for a rank
    /// that couldn't be computed.
    private func pbBanner(_ banner: PostDetailViewModel.TestBanner) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(banner.distanceLabel.uppercased()) TEST")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Tokens.Accent.records)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(banner.valueLabel)
                    .font(.system(size: 32, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Accent.records)
                if banner.isPersonalBest {
                    Text("Personal best")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            if let text = rankText(banner) {
                Text(text)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.primary.opacity(0.8))
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Tokens.Accent.records.opacity(0.32), lineWidth: 1)
        }
    }

    private func rankText(_ banner: PostDetailViewModel.TestBanner) -> String? {
        var parts: [String] = []
        if let overall = banner.overallRank { parts.append("\(overall.formattedOrdinal) overall") }
        if let category = banner.categoryRank, let label = banner.categoryLabel {
            parts.append("\(category.formattedOrdinal) \(label)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private var sessionTotalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SESSION TOTAL")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer()
                if viewModel.photoVerified {
                    Label("Photo-verified", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Tokens.Accent.brand)
                } else if viewModel.loggedLate {
                    Text("Logged later")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Tokens.Ink.primary.opacity(0.8))
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(viewModel.totalDistanceM.formattedDistance(unit: distanceUnit))
                    .font(.system(size: 24, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text(totalTimeAndSplitLabel)
                    .textStyle(Typography.bodySecondary)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            if let caption = viewModel.caption, !caption.isEmpty {
                Text(caption)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.primary.opacity(0.85))
            }
            VStack(spacing: 8) {
                ForEach(viewModel.segments) { segment in
                    detailSegmentRow(segment)
                }
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 22)
    }

    /// "1:04:50 · 2:01.6 /500m" for split, "1:04:50 · 186W" for watts — the
    /// hand-appended "/500m" only makes sense alongside an actual split.
    private var totalTimeAndSplitLabel: String {
        let split = viewModel.avgSplitMs?.formattedPace(display: paceDisplay) ?? "—"
        let time = viewModel.totalTimeMs.formattedDurationMs
        return paceDisplay == .split ? "\(time) · \(split) /500m" : "\(time) · \(split)"
    }

    private func detailSegmentRow(_ segment: PostDetailViewModel.DetailSegment) -> some View {
        HStack(spacing: 10) {
            CachedAsyncImage(url: segment.monitorPhotoPath.flatMap { viewModel.monitorURLs[$0] }) {
                Rectangle().fill(Tokens.Ink.primary.opacity(0.08))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(segment.label.rawValue.uppercased())
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 64, alignment: .leading)
            Text(segment.distanceM.formattedDistance(unit: distanceUnit))
                .font(.system(size: 13.5, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .frame(width: 60, alignment: .leading)
            Text(segment.timeMs.formattedDurationMs)
                .font(.system(size: 13))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(segment.splitMs?.formattedPace(display: paceDisplay) ?? "—")
                .font(.system(size: 13))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
            Text(segment.rate.map { "r\(Int($0.rounded()))" } ?? "—")
                .font(.system(size: 13))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary.opacity(0.85))
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var reactionRow: some View {
        HStack(spacing: 7) {
            ForEach(viewModel.reactions) { reaction in
                reactionChip(reaction)
            }
            Spacer()
            Button {
                isShowingMoreReactions = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.secondary)
                    .frame(width: 34, height: 34)
                    .background {
                        Circle().fill(Tokens.Ink.primary.opacity(0.08))
                    }
            }
            .buttonStyle(.plain)
            .confirmationDialog("Add a reaction", isPresented: $isShowingMoreReactions, titleVisibility: .visible) {
                ForEach(PostDetailViewModel.extraReactionKinds, id: \.self) { kind in
                    Button("\(Self.emoji[kind] ?? "") \(kind.capitalized)") {
                        Task { await viewModel.toggleReaction(kind: kind) }
                    }
                }
            }
        }
    }

    private func reactionChip(_ reaction: PostDetailViewModel.ReactionSummary) -> some View {
        Button {
            Task { await viewModel.toggleReaction(kind: reaction.kind) }
        } label: {
            HStack(spacing: 5) {
                Text(Self.emoji[reaction.kind] ?? "•")
                Text("\(reaction.count)")
                    .tabularNumerals()
                    .fontWeight(reaction.reactedByMe ? .semibold : .regular)
                    .foregroundStyle(reaction.reactedByMe ? Tokens.Accent.records : Tokens.Ink.secondary)
            }
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule().fill((reaction.reactedByMe ? Tokens.Accent.records : Tokens.Ink.primary).opacity(reaction.reactedByMe ? 0.16 : 0.08))
            }
        }
        .buttonStyle(.plain)
    }

    private var commentThread: some View {
        VStack(spacing: 8) {
            if viewModel.comments.isEmpty {
                Text("No comments yet.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            ForEach(viewModel.comments) { comment in
                HStack(alignment: .top, spacing: 10) {
                    AvatarPlaceholder(diameter: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 7) {
                            Text(comment.authorName)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Tokens.Ink.primary)
                            Text(comment.createdAt.postedAgoLabel)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Tokens.Ink.secondary.opacity(0.8))
                        }
                        Text(comment.body)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Tokens.Ink.primary.opacity(0.85))
                    }
                    Spacer()
                }
                .padding(11)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Tokens.Ink.primary.opacity(0.05))
                }
                .contextMenu {
                    if !viewModel.isOwnComment(comment) {
                        Button {
                            commentBeingReported = comment.id
                            isShowingReportReasons = true
                        } label: {
                            Label("Report comment", systemImage: "flag")
                        }
                    }
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Say something…", text: $commentDraft)
                .textStyle(Typography.body)
                .foregroundStyle(Tokens.Ink.primary)
                .focused($isComposerFocused)
            Spacer()
            Button {
                let text = commentDraft
                commentDraft = ""
                Task { await viewModel.postComment(body: text) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tokens.Base.dark)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle().fill(commentDraft.trimmingCharacters(in: .whitespaces).isEmpty ? Tokens.Accent.brand.opacity(0.4) : Tokens.Accent.brand)
                    }
            }
            .buttonStyle(.plain)
            .disabled(commentDraft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: 50)
        .glassSurface(cornerRadius: 25)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}
