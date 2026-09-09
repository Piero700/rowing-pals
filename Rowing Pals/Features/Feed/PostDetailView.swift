//
//  PostDetailView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 8 — full segment breakdown, reactions, comment thread. Realtime
/// reactions/comments and follow/unfollow arrive with task 16; this is the
/// static shell.
struct PostDetailView: View {
    let session: MockFeedSession
    @Environment(\.dismiss) private var dismiss

    private struct MockComment: Identifiable {
        let id = UUID()
        let name: String
        let when: String
        let text: String
    }

    private let comments = [
        MockComment(name: "Nina Bergström", when: "42m", text: "that's a 4 second PB, well in"),
        MockComment(name: "Piero Ciobanu", when: "31m", text: "rate 33 is criminal"),
        MockComment(name: "Freya Lomax", when: "12m", text: "see you at 6am")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero

                VStack(alignment: .leading, spacing: 12) {
                    if session.isPersonalBest {
                        pbBanner
                    }
                    sessionTotalCard
                    reactionRow
                    commentThread
                }
                .padding(14)
                .padding(.bottom, 80)
            }
        }
        .background(Tokens.Base.ground)
        .overlay(alignment: .bottom) {
            composer
        }
        .ignoresSafeArea(edges: .top)
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            PhotoPlaceholder(cornerRadius: 0, caption: session.photoCaption)
                .frame(height: 330)

            PhotoPlaceholder(cornerRadius: 18, caption: "SELFIE · TAP TO SWAP")
                .frame(width: 86, height: 116)
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

            HStack(spacing: 9) {
                AvatarPlaceholder(diameter: 24)
                Text(session.authorName)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule().fill(.ultraThinMaterial)
            }
            .padding(.top, 54)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 14)
        }
        .frame(height: 330)
        .clipped()
    }

    private var pbBanner: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("2K TEST · PERSONAL BEST")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Tokens.Accent.pb)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(session.headline)
                    .font(.system(size: 32, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Accent.pb)
                Text("1:46.0 /500m · r34")
                    .textStyle(Typography.bodySecondary)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Text("1st overall women · 1st senior women")
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Ink.primary.opacity(0.8))
        }
        .padding(14)
        .glassSurface(cornerRadius: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Tokens.Accent.pb.opacity(0.32), lineWidth: 1)
        }
    }

    private var sessionTotalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SESSION TOTAL")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer()
                Label("Photo-verified", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Tokens.Accent.signal)
            }
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("6,000m")
                    .font(.system(size: 24, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("25:14.8 · 2:06.2 /500m")
                    .textStyle(Typography.bodySecondary)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            VStack(spacing: 8) {
                detailSegmentRow(tag: "WARMUP", dist: "2,000m", time: "8:40.0", split: "2:10.0", rate: "r18")
                detailSegmentRow(tag: "MAIN", dist: "2,000m", time: "7:04.1", split: "1:46.0", rate: "r34")
                detailSegmentRow(tag: "COOLDOWN", dist: "2,000m", time: "9:30.7", split: "2:22.7", rate: "r16")
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 22)
    }

    private func detailSegmentRow(tag: String, dist: String, time: String, split: String, rate: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.08))
                .frame(width: 38, height: 38)
            Text(tag)
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 64, alignment: .leading)
            Text(dist)
                .font(.system(size: 13.5, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .frame(width: 60, alignment: .leading)
            Text(time)
                .font(.system(size: 13))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(split)
                .font(.system(size: 13))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
            Text(rate)
                .font(.system(size: 13))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary.opacity(0.85))
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var reactionRow: some View {
        HStack(spacing: 7) {
            reactionChip(emoji: "🔥", count: session.reactions.fire, highlighted: true)
            reactionChip(emoji: "😬", count: 6)
            reactionChip(emoji: "👏", count: 19)
            reactionChip(emoji: "👀", count: 8)
            Spacer()
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(Tokens.Ink.primary.opacity(0.08))
                }
        }
    }

    private func reactionChip(emoji: String, count: Int, highlighted: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(emoji)
            Text("\(count)")
                .tabularNumerals()
                .fontWeight(highlighted ? .bold : .regular)
                .foregroundStyle(highlighted ? Tokens.Accent.pb : Tokens.Ink.secondary)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule().fill((highlighted ? Tokens.Accent.pb : Tokens.Ink.primary).opacity(highlighted ? 0.16 : 0.08))
        }
    }

    private var commentThread: some View {
        VStack(spacing: 8) {
            ForEach(comments) { comment in
                HStack(alignment: .top, spacing: 10) {
                    AvatarPlaceholder(diameter: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 7) {
                            Text(comment.name)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Tokens.Ink.primary)
                            Text(comment.when)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Tokens.Ink.secondary.opacity(0.8))
                        }
                        Text(comment.text)
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
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Text("Say something…")
                .textStyle(Typography.body)
                .foregroundStyle(Tokens.Ink.secondary)
            Spacer()
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Tokens.Base.dark)
                .frame(width: 38, height: 38)
                .background {
                    Circle().fill(Tokens.Accent.signal)
                }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: 50)
        .glassSurface(cornerRadius: 25)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

#Preview {
    PostDetailView(session: .personalBest)
}
