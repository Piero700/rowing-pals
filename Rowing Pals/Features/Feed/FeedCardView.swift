//
//  FeedCardView.swift
//  Rowing Pals
//

import SwiftUI

/// One feed card, built from a real `FeedPost` — header row, monitor photo
/// full-bleed with the selfie as a tappable swap inset, a glass data strip,
/// segment chips, and the verification badge. Anatomy matches the design
/// brief's Screen 2. The reaction row there is task 16's — real reactions
/// don't exist yet, so this doesn't show a fabricated one.
struct FeedCardView: View {
    let post: FeedPost
    let monitorURL: URL?
    let selfieURL: URL?
    /// The author's current streak, resolved by `FeedViewModel`'s batched
    /// `daily_totals` fetch — 0 (no badge) until that resolves. See
    /// `AvatarPlaceholder`'s doc comment.
    var streakDays: Int = 0

    /// Tap-to-swap, BeReal-style — which photo is full-bleed right now.
    @State private var isSelfiePrimary = false
    @Environment(\.navigate) private var navigate
    /// Redesign phase B — per-device display preferences, not synced to
    /// the profile. See DesignSystem/PaceDisplay.swift.
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    private var primaryURL: URL? { isSelfiePrimary ? selfieURL : monitorURL }
    private var insetURL: URL? { isSelfiePrimary ? monitorURL : selfieURL }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: primaryURL) {
                    PhotoPlaceholder(cornerRadius: 0, caption: "MONITOR PHOTO")
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: 300)
                .clipped()

                Button {
                    withAnimation(.snappy) { isSelfiePrimary.toggle() }
                } label: {
                    CachedAsyncImage(url: insetURL) {
                        PhotoPlaceholder(cornerRadius: 16, caption: "SELFIE")
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 84, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(12)

                verificationBadge
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                VStack {
                    Spacer()
                    dataStrip
                        .padding(10)
                }
            }
            .frame(height: 300)
            .clipped()

            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, post.segments.isEmpty ? 14 : 6)
            }

            if !post.segments.isEmpty {
                HStack(spacing: 7) {
                    ForEach(post.segments.sorted { $0.position < $1.position }) { segment in
                        FilterChip(
                            label: "\(segment.label.rawValue.uppercased()) \(segment.distanceM.formattedMetres)",
                            isSelected: segment.label == .main
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, (post.caption?.isEmpty ?? true) ? 12 : 8)
                .padding(.bottom, 14)
            }
        }
        .background(Tokens.Ink.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 10) {
            // Avatar + name open the author's profile (a route, not a direct
            // reference — see `AppRoute`).
            HStack(spacing: 10) {
            AvatarPlaceholder(diameter: 36, streakDays: streakDays)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    Text(post.author.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(categoryTag)
                        .textStyle(Typography.label)
                        .textCase(nil)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Tokens.Ink.primary.opacity(0.12))
                        }
                }
                if let club = post.author.club?.name {
                    Text(club)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            }
            .contentShape(Rectangle())
            .onTapGesture { navigate(.profile(post.userId)) }
            Spacer()
            Text(post.postedAt.postedAgoLabel)
                .textStyle(Typography.bodySecondary)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var categoryTag: String {
        let category = post.author.category.rawValue.uppercased()
        guard let gender = post.author.gender?.rawValue else { return category }
        return "\(category) · \(gender)"
    }

    private var verificationBadge: some View {
        Group {
            if post.photoVerified {
                Label("Photo-verified", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Tokens.Accent.brand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule().fill(Tokens.Accent.brand.opacity(0.18))
                    }
            } else if post.loggedLate {
                Text("Logged later")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule().fill(Tokens.Ink.primary.opacity(0.14))
                    }
            }
        }
    }

    /// "AVG /500M" only means something for a split value — once the
    /// preference is watts, the label has to stop implying a distance unit.
    private var avgSplitLabel: String {
        paceDisplay == .split ? "AVG /500M" : "AVG WATTS"
    }

    private var dataStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(post.totalDistanceM.formattedMetres)
                    .font(.system(size: 34, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
            }
            HStack(spacing: 22) {
                StatColumn(label: "TIME", value: post.totalTimeMs.formattedDurationMs)
                StatColumn(label: avgSplitLabel, value: post.avgSplitMs?.formattedPace(display: paceDisplay) ?? "—")
                StatColumn(label: "RATE", value: post.avgRate.map { "r\(Int($0.rounded()))" } ?? "—")
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 22)
    }
}
