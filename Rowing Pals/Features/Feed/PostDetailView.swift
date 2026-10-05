//
//  PostDetailView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 8 — one post, opened. Redesign phase (docs/design/rowing-pals-redesign-handoff-v2.md
/// §2 "post"/workout-detail, §3 "Workout-hero photo-first detail"): a full-bleed dual-camera
/// photo up top with a floating back button and a glass "person pill", then the rest of the
/// content scrolls up under a rounded sheet-lip edge — totals, a collapsible split breakdown,
/// reactions, caption, an optional extra-photo gallery, up to 3 inline recent comments ("View
/// all" opens the full thread when there are more), and a sticky composer. The gold test-result
/// banner (design-brief.md Screen 8) still renders first in the sheet when the post was a
/// confirmed test. Reactions and comments arrive live via Realtime (task 16).
struct PostDetailView: View {
    @State private var viewModel: PostDetailViewModel
    @State private var isSelfiePrimary = false
    @State private var isSplitBreakdownExpanded = true
    @State private var commentDraft = ""
    @State private var isShowingMoreReactions = false
    @State private var isShowingReportReasons = false
    @State private var isShowingReportConfirmation = false
    @State private var isShowingBlockConfirmation = false
    @State private var commentBeingReported: UUID?
    @State private var isShowingAllComments = false
    /// Called with the comment total whenever it changes, so the feed card underneath updates.
    private let onCommentCountChange: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate
    /// Redesign phase B — per-device display preferences, not synced to
    /// the profile. See DesignSystem/PaceDisplay.swift.
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    /// Emoji for any stored reaction kind, including those added from the feed's v3 picker.
    private static var emoji: [String: String] {
        Dictionary(uniqueKeysWithValues: (ReactionCatalog.picker + ReactionCatalog.legacy).map { ($0.key, $0.emoji) })
    }
    private static let reportReasons = ["Inappropriate content", "Spam", "Harassment", "Other"]
    private static let heroHeight: CGFloat = 420
    /// How far the rounded sheet-lip rides up over the hero photo's bottom
    /// edge. An `.offset`, not extra padding, so it doesn't add a matching
    /// empty gap to the scroll content — see `sheetLip`.
    private static let lipOverlap: CGFloat = 28
    private static let maxInlineComments = 3

    init(sessionId: UUID, onCommentCountChange: @escaping (Int) -> Void = { _ in }) {
        _viewModel = State(initialValue: PostDetailViewModel(sessionId: sessionId))
        self.onCommentCountChange = onCommentCountChange
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                sheetLip
            }
        }
        .background(Tokens.Base.ground)
        .dismissesKeyboardOnTap()
        .edgeSwipeToDismiss()
        .overlay(alignment: .bottom) {
            composer
        }
        .onChange(of: viewModel.thread.comments.count) { _, count in
            onCommentCountChange(count)
        }
        .fullScreenCover(isPresented: $isShowingAllComments) {
            CommentsView(thread: viewModel.thread, subtitle: threadSubtitle)
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
                            sent = await viewModel.thread.reportComment(commentId, reason: reason)
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

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            CachedAsyncImage(url: primaryURL) {
                PhotoPlaceholder(cornerRadius: 0, caption: "MONITOR PHOTO")
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: Self.heroHeight)
            .clipped()

            // Tap-to-swap, BeReal-style — unchanged from the pre-redesign
            // screen, just repositioned under the back button.
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

            backButton
                .padding(.leading, 14)
                .padding(.top, 54)

            if !viewModel.isOwnPost {
                moreOptionsButton
                    .padding(.trailing, 14)
                    .padding(.top, 54)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 8) {
                    personPill
                    Spacer(minLength: 8)
                    if !viewModel.isOwnPost {
                        followButton
                    }
                }
            }
            .padding(.horizontal, 14)
            // Clears the sheet-lip that rides up over the photo's bottom
            // `Self.lipOverlap` points — otherwise the pill would sit half
            // under the rounded card edge.
            .padding(.bottom, Self.lipOverlap + 18)
        }
        .frame(height: Self.heroHeight)
        .clipped()
    }

    /// Shared look for the two floating circular glass icon buttons over
    /// the photo (back, more-options) — a darkened, specular-rimmed circle
    /// distinct from `glassSurface`'s flat card shape, since these sit
    /// directly on photo content rather than the sheet background.
    private func floatingIconStyle(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(Color.black.opacity(0.28))
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
            // 36 pt to look at, 44 pt to tap.
            .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
            .contentShape(Circle())
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            floatingIconStyle("chevron.left")
        }
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
            floatingIconStyle("ellipsis")
        }
    }

    /// Avatar + name + chevron, glass pill, tappable → that person's
    /// profile — docs/design/rowing-pals-redesign-handoff-v2.md §3. Raises a
    /// route rather than naming the profile screen, since a feature can't
    /// import another feature (see `AppRoute`).
    private var personPill: some View {
        Button(action: handlePersonPillTap) {
            HStack(spacing: 8) {
                AvatarPlaceholder(diameter: 28, streakDays: viewModel.authorStreakDays, name: viewModel.author?.displayName, userId: viewModel.author?.id)
                Text(viewModel.author?.displayName ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .glassSurface(cornerRadius: 999)
        }
        .buttonStyle(.plain)
    }

    private func handlePersonPillTap() {
        guard let authorId = viewModel.author?.id else { return }
        navigate(.profile(authorId))
    }

    private var followButton: some View {
        FollowButton(
            state: viewModel.followState,
            followsYou: viewModel.authorFollowsViewer,
            isBusy: viewModel.isFollowBusy,
            variant: .compactPill
        ) {
            Task { await viewModel.toggleFollow() }
        }
    }

    // MARK: - Sheet lip

    /// Everything below the photo, on a rounded-top surface that rides up
    /// `Self.lipOverlap` points over the hero's bottom edge — the
    /// "sheet-lip" effect from the handoff doc. Uses `Tokens.Base.ground`
    /// (the screen/card ground token), not `glassSurface`: this is the
    /// primary content background, not a floating chip or bar over photo
    /// content, so it stays consistent with how the rest of the app uses
    /// that token rather than inventing a new translucent primitive.
    private var sheetLip: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let banner = viewModel.testBanner {
                pbBanner(banner)
            }
            totalsCard
            splitBreakdownCard
            if !viewModel.reactions.isEmpty {
                reactionRow
            }
            captionText
            extraPhotoGallery
            commentThread
        }
        .padding(.horizontal, 14)
        .padding(.top, Self.lipOverlap + 18)
        .padding(.bottom, 120)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Tokens.Base.ground)
        }
        .offset(y: -Self.lipOverlap)
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

    // MARK: - Totals

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SESSION TOTAL")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer()
                // No "Photo-verified" label (decision 38): verification still decides what
                // reaches the leaderboards, it just isn't shown.
                if !viewModel.photoVerified, viewModel.loggedLate {
                    Text("Logged later")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Tokens.Ink.primary.opacity(0.8))
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(viewModel.totalDistanceM.formattedMetres)
                    .font(.system(size: 24, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text(totalTimeAndSplitLabel)
                    .textStyle(Typography.bodySecondary)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
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

    // MARK: - Split breakdown (collapsible)

    /// Was always-expanded pre-redesign; the handoff calls specifically for
    /// a collapsible breakdown here. Defaults open so the information
    /// people most often come to a post for (their splits) is still
    /// visible without an extra tap — "collapsible" is about giving people
    /// a way to declutter, not hiding the data by default.
    private var splitBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { isSplitBreakdownExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("SPLIT BREAKDOWN")
                        .textStyle(Typography.label)
                        .foregroundStyle(Tokens.Ink.secondary)
                    Text("\(viewModel.segments.count)")
                        .textStyle(Typography.label)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.faint)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Tokens.Ink.secondary)
                        .rotationEffect(.degrees(isSplitBreakdownExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isSplitBreakdownExpanded {
                VStack(spacing: 8) {
                    ForEach(viewModel.segments) { segment in
                        detailSegmentRow(segment)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 22)
    }

    private func detailSegmentRow(_ segment: PostDetailViewModel.DetailSegment) -> some View {
        HStack(spacing: 10) {
            CachedAsyncImage(url: segment.monitorPhotoPath.flatMap { viewModel.monitorURLs[$0] }) {
                Rectangle().fill(Tokens.Ink.primary.opacity(0.08))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(viewModel.badgeText(for: segment))
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 64, alignment: .leading)
            Text(segment.distanceM.formattedMetres)
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

    // MARK: - Reactions

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
                    .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                .contentShape(Circle())
            }
            .accessibilityLabel("More reactions")
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

    // MARK: - Caption

    @ViewBuilder
    private var captionText: some View {
        if let caption = viewModel.caption, !caption.isEmpty {
            Text(caption)
                .textStyle(Typography.body)
                .foregroundStyle(Tokens.Ink.primary.opacity(0.9))
        }
    }

    // MARK: - Extra-photo gallery

    /// "An optional extra-photo gallery, only if the session has extra
    /// photos beyond the two dual-camera shots." The data model has no
    /// separate photo-gallery field (see `Session`/`Segment` — one monitor
    /// photo per segment, one selfie per session); the real equivalent
    /// here is any *other* segment's monitor photo (warmup/cooldown/extra)
    /// beyond the hero segment already shown full-bleed up top. Only
    /// renders at all when at least one exists.
    private var extraPhotoSegments: [PostDetailViewModel.DetailSegment] {
        viewModel.segments.dropFirst().filter { $0.monitorPhotoPath != nil }
    }

    @ViewBuilder
    private var extraPhotoGallery: some View {
        if !extraPhotoSegments.isEmpty || !viewModel.galleryPaths.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("MORE PHOTOS")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // Photos the rower added in the review screen's photo
                        // strip come first, then other pieces' monitor photos.
                        ForEach(viewModel.galleryPaths, id: \.self) { path in
                            CachedAsyncImage(url: viewModel.monitorURLs[path]) {
                                PhotoPlaceholder(cornerRadius: 18, caption: nil)
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        ForEach(extraPhotoSegments) { segment in
                            CachedAsyncImage(url: segment.monitorPhotoPath.flatMap { viewModel.monitorURLs[$0] }) {
                                PhotoPlaceholder(cornerRadius: 18, caption: segment.label.rawValue.uppercased())
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Comments

    /// The last 3 comments inline; with more, "View all" opens the full thread (handoff §2
    /// `comments`), which shares this screen's `CommentThread`.
    private var recentComments: [CommentThread.Entry] {
        Array(viewModel.thread.comments.suffix(Self.maxInlineComments))
    }

    /// "Joe Bloggs · UT2" — the thread screen's line under its title.
    private var threadSubtitle: String {
        "\(viewModel.author?.displayName ?? "") · \(viewModel.workoutLabel ?? "Training")"
    }

    private var commentThread: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.gap) {
            HStack {
                Text("COMMENTS")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.secondary)
                if viewModel.thread.comments.count > Self.maxInlineComments {
                    Spacer()
                    Button {
                        isShowingAllComments = true
                    } label: {
                        Text("View all \(viewModel.thread.comments.count)")
                            .textStyle(Typography.pill)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Accent.brand)
                            .frame(minHeight: Tokens.Size.minTap)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View all \(viewModel.thread.comments.count) comments")
                }
            }

            if viewModel.thread.comments.isEmpty {
                Text("No comments yet.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }

            ForEach(recentComments) { comment in
                CommentRow(comment: comment, canReport: !viewModel.thread.isOwnComment(comment)) {
                    commentBeingReported = comment.id
                    isShowingReportReasons = true
                }
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 6) {
            if let errorMessage = viewModel.thread.errorMessage {
                Text(errorMessage)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.System.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Tokens.Spacing.headerHorizontal)
            }
            CommentComposer(draft: $commentDraft) { text in
                Task { await viewModel.thread.postComment(body: text) }
            }
        }
    }
}
