//
//  PostDetailView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 8 — one post, opened. Redesign phase (docs/design/rowing-pals-redesign-handoff-v2.md
/// §2 "post"/workout-detail, §3 "Workout-hero photo-first detail"): a full-bleed dual-camera
/// photo up top with a floating back button and a glass "person pill", then the rest of the
/// content scrolls up under a rounded sheet-lip edge — totals, a collapsible split breakdown,
/// reactions, caption, an optional extra-photo gallery, up to 3 inline recent comments, and a
/// sticky composer. The gold test-result banner (design-brief.md Screen 8) still renders first
/// in the sheet when the post was a confirmed test. Reactions and comments still arrive live via
/// Realtime (task 16) — this rebuild only restructures layout, `PostDetailViewModel` is untouched.
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
    private static let heroHeight: CGFloat = 420
    /// How far the rounded sheet-lip rides up over the hero photo's bottom
    /// edge. An `.offset`, not extra padding, so it doesn't add a matching
    /// empty gap to the scroll content — see `sheetLip`.
    private static let lipOverlap: CGFloat = 28
    private static let maxInlineComments = 3

    init(sessionId: UUID) {
        _viewModel = State(initialValue: PostDetailViewModel(sessionId: sessionId))
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
    /// profile — docs/design/rowing-pals-redesign-handoff-v2.md §3.
    ///
    /// The tap target itself is fully built and styled; the action is
    /// currently a no-op. There is no "other rower's profile" screen
    /// anywhere in this codebase yet (the handoff doc's §2 lists it as
    /// Screen 08, not built), and CLAUDE.md's "no feature imports another
    /// feature" rule means `Features/Feed` can't reach into
    /// `Features/Profile` even for the viewer's own post — that needs
    /// either Screen 08 built or a shared cross-feature router, neither of
    /// which exists. Wiring that up is out of scope for this layout-only
    /// rebuild; see `handlePersonPillTap()`.
    private var personPill: some View {
        Button(action: handlePersonPillTap) {
            HStack(spacing: 8) {
                AvatarPlaceholder(diameter: 28, streakDays: viewModel.authorStreakDays)
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
        // Intentionally a no-op — see the doc comment on `personPill`.
    }

    private var followButton: some View {
        Button {
            Task { await viewModel.toggleFollow() }
        } label: {
            Text(viewModel.isFollowingAuthor ? "Following" : "Follow")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(viewModel.isFollowingAuthor ? Tokens.Ink.primary : Tokens.Base.dark)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if viewModel.isFollowingAuthor {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().fill(Tokens.Ink.primary.opacity(0.16))
                    } else {
                        Capsule().fill(Tokens.Accent.brand)
                    }
                }
        }
        .buttonStyle(.plain)
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
        if !extraPhotoSegments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("MORE PHOTOS")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
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

    /// Up to 3 inline, most recent first-in-thread order (the full thread
    /// is chronological ascending already) — a dedicated full-thread
    /// screen is its own view per the handoff (§2 `comments`) and isn't
    /// part of this layout rebuild, so once there are more than 3 this
    /// just surfaces the total count rather than linking anywhere.
    private var recentComments: [PostDetailViewModel.CommentDisplay] {
        Array(viewModel.comments.suffix(Self.maxInlineComments))
    }

    private var commentThread: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("COMMENTS")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.secondary)
                if viewModel.comments.count > Self.maxInlineComments {
                    Spacer()
                    Text("\(viewModel.comments.count) total")
                        .textStyle(Typography.bodySecondary)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.faint)
                }
            }

            if viewModel.comments.isEmpty {
                Text("No comments yet.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }

            ForEach(recentComments) { comment in
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

    // MARK: - Composer

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
