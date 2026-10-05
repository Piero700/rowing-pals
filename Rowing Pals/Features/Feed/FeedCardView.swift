//
//  FeedCardView.swift
//  Rowing Pals
//

import SwiftUI

/// One v3 feed post (docs/design/rowing-pals-v3-spec.md §Feed post card, exact values from
/// `docs/design/v3/RP Screen.dc.html` §02): header, 4:3 photo carousel, the lead piece's
/// numbers, caption, workout link, reactions, comments and share. A new PB glows.
///
/// Only specific parts are tappable — never the whole card: the header opens the author's
/// profile; the photo and workout link open the post; the comments pill opens the thread; the
/// selfie inset swaps; each pill reacts. That keeps every tap unambiguous, including taps near the floating tab bar.
struct FeedCardView: View {
    let post: FeedPost
    /// Signed URL for any photo path on this post.
    let photoURL: (String) -> URL?
    let selfieURL: URL?
    var streakDays: Int = 0
    var reactions: [FeedViewModel.ReactionSummary] = []
    var onOpen: () -> Void = {}
    var onOpenComments: () -> Void = {}
    var onToggleReaction: (String) -> Void = { _ in }

    @State private var page = 0
    @State private var isSelfiePrimary = false
    @State private var isShowingReactionPicker = false
    @State private var isShowingShare = false
    @Environment(\.navigate) private var navigate
    /// Redesign phase B — per-device pace display preference.
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let photoShape = RoundedRectangle(cornerRadius: Tokens.Radius.photo, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            carousel
                .padding(.top, 14)
            metricTrio
                .padding(.vertical, Tokens.Spacing.loose)
            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .textStyle(Typography.bodyV3)
                    .lineSpacing(4)
                    .foregroundStyle(Tokens.Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
                    .padding(.bottom, 9)
            }
            workoutLink
            reactionRow
                .padding(.top, 14)
            actionRow
                .padding(.top, Tokens.Spacing.loose)
        }
        .padding(Tokens.Spacing.card)
        .background { Self.cardShape.fill(Tokens.Surface.card) }
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1).allowsHitTesting(false) }
        .pbGlow(post.isNewPB, in: Self.cardShape)
        .sheet(isPresented: $isShowingReactionPicker) {
            reactionPicker
                .presentationDetents([.height(290)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        Button {
            navigate(.profile(post.userId))
        } label: {
            HStack(spacing: 11) {
                AvatarPlaceholder(diameter: 41, streakDays: streakDays, name: post.author.displayName, userId: post.userId)
                VStack(alignment: .leading, spacing: 0) {
                    Text(post.author.displayName)
                        .textStyle(Typography.name)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    if let club = post.author.club?.name {
                        Text(club)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: Tokens.Size.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(post.author.displayName), \(post.author.club?.name ?? "no club"). Open profile")
    }

    // MARK: - Photo carousel

    private var carousel: some View {
        let pages = post.pages
        return ZStack(alignment: .bottom) {
            if pages.isEmpty {
                Button(action: onOpen) {
                    PhotoPlaceholder(cornerRadius: Tokens.Radius.photo, caption: "MANUAL ENTRY")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open workout")
            } else {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                        pageView(item, isLeadPage: index == 0)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if pages.count > 1 {
                    pageDots(count: pages.count)
                        .padding(.bottom, 10)
                        .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipShape(Self.photoShape)
    }

    private func pageView(_ item: FeedPost.Page, isLeadPage: Bool) -> some View {
        // The selfie belongs with the lead piece; photographed sessions only.
        let hasInset = isLeadPage && post.photoVerified && selfieURL != nil
        let mainURL = hasInset && isSelfiePrimary ? selfieURL : photoURL(item.path)
        let insetURL = isSelfiePrimary ? photoURL(item.path) : selfieURL
        return GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                Button(action: onOpen) {
                    CachedAsyncImage(url: mainURL) {
                        PhotoPlaceholder(cornerRadius: 0, caption: nil)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pageAccessibilityLabel(item))

                if hasInset {
                    Button {
                        withAnimation(.snappy) { isSelfiePrimary.toggle() }
                    } label: {
                        CachedAsyncImage(url: insetURL) {
                            PhotoPlaceholder(cornerRadius: Tokens.Radius.photoInset, caption: nil)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width * 0.27, height: geometry.size.height * 0.37)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photoInset, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Tokens.Radius.photoInset, style: .continuous)
                                .strokeBorder(Tokens.Surface.card, lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.33), radius: 7, y: 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityLabel("Swap photos")
                }
            }
        }
    }

    private func pageAccessibilityLabel(_ item: FeedPost.Page) -> String {
        switch item.kind {
        case .monitor(let segment): "\(segment.label.rawValue.capitalized) piece photo. Open workout"
        case .environment: "Session photo. Open workout"
        }
    }

    private func pageDots(count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index == page ? 1 : 0.45))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background { Capsule().fill(Color.black.opacity(0.35)) }
        .accessibilityHidden(true)
    }

    // MARK: - Numbers

    /// The lead piece's own distance, time and pace (decision 16) — the most intense piece, not
    /// the whole session.
    private var metricTrio: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.tight) {
            metric("Distance", post.leadDistanceM.formattedMetres)
            metric("Time", post.leadTimeMs.formattedDurationMs)
            metric(paceDisplay == .split ? "/500m" : "Watts", post.leadSplitMs.map { $0.formattedPace(display: paceDisplay) } ?? "—")
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .textStyle(Typography.metricLabel)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(value)
                .textStyle(Typography.metricValue)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Workout link

    /// "UT2 · Main workout" over the whole session's totals; opens the post.
    private var workoutLink: some View {
        let pieces = post.segments.count
        let meta = [
            post.totalDistanceM.formattedMetres,
            post.totalTimeMs.formattedDurationMs,
            pieces == 1 ? "1 piece" : "\(pieces) pieces"
        ].joined(separator: " · ")
        return Button(action: onOpen) {
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(post.workoutLabel ?? "Training") · Main workout")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(meta)
                        .font(.system(size: 12))
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
            }
            .padding(Tokens.Spacing.card)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Tokens.Radius.workoutLink, style: .continuous)
                    .fill(Tokens.Surface.raised)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.workoutLink, style: .continuous)
                    .strokeBorder(Tokens.Surface.line, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.workoutLink, style: .continuous))
        }
        .buttonStyle(IconPressStyle())
    }

    // MARK: - Reactions

    private var reactionRow: some View {
        WrapLayout(spacing: Tokens.Spacing.tight) {
            ForEach(reactions) { reaction in
                Button {
                    onToggleReaction(reaction.kind)
                } label: {
                    Text("\(ReactionCatalog.emoji(for: reaction.kind)) \(reaction.count)")
                        .tabularNumerals()
                }
                .buttonStyle(.rpPill(isOn: reaction.isMine, minHeight: 40))
                .accessibilityLabel("\(ReactionCatalog.kind(for: reaction.kind)?.name ?? reaction.kind), \(reaction.count)")
                .accessibilityAddTraits(reaction.isMine ? .isSelected : [])
            }
            Button {
                isShowingReactionPicker = true
            } label: {
                // U+FE0E asks for the plain text glyph, not the colour emoji, as in v3.
                Text("＋☺\u{FE0E}")
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .buttonStyle(.rpPill(isOn: false, minHeight: 40))
            .accessibilityLabel("Choose a reaction")
        }
    }

    private var reactionPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a reaction")
                .textStyle(Typography.navTitle)
                .foregroundStyle(Tokens.Ink.primary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(ReactionCatalog.picker) { kind in
                    let isMine = reactions.contains { $0.kind == kind.key && $0.isMine }
                    Button {
                        // Picking adds a reaction; it never removes one (that's the pill's job).
                        if !isMine { onToggleReaction(kind.key) }
                        isShowingReactionPicker = false
                    } label: {
                        Text(kind.emoji)
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isMine ? Tokens.Accent.brandSoft : Tokens.Surface.raised)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(IconPressStyle())
                    .accessibilityLabel(kind.name)
                    .accessibilityAddTraits(isMine ? .isSelected : [])
                }
            }
        }
        .padding(Tokens.Spacing.screen + 5)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Tokens.Base.ground)
    }

    // MARK: - Comments and share

    private var actionRow: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            Button(action: onOpenComments) {
                Label(
                    post.commentCount == 1 ? "1 comment" : "\(post.commentCount) comments",
                    systemImage: "bubble.left"
                )
                .tabularNumerals()
            }
            .buttonStyle(.rpPill)

            Spacer(minLength: 0)

            Button {
                isShowingShare = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                    .glassSurface(in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(IconPressStyle())
            .accessibilityLabel("Share workout")
        }
        .padding(.top, 9)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Surface.line).frame(height: 1)
        }
        .sheet(isPresented: $isShowingShare) {
            ShareWorkoutSheet(post: post, photoURL: post.pages.first.flatMap { photoURL($0.path) })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
