//
//  SessionCardView.swift
//  Rowing Pals
//

import SwiftUI

/// Mock data for one feed card. Real sessions/segments arrive with task 12's
/// Supabase query — this mirrors the shape closely so the swap is mechanical.
struct MockFeedSession: Identifiable {
    struct Segment {
        let tag: String
        let distanceLabel: String
    }

    struct Reactions {
        let fire: Int
        let grimace: Int
        let clap: Int
        let commentCount: Int
    }

    let id = UUID()
    let authorName: String
    let authorTag: String
    let club: String
    let postedAgo: String
    let caption: String
    let isPersonalBest: Bool
    let isWaterOuting: Bool
    let photoCaption: String
    let headline: String
    let headlineUnit: String
    let stats: [(label: String, value: String)]
    let segments: [Segment]
    let reactions: Reactions
}

extension MockFeedSession {
    static let steadyState = MockFeedSession(
        authorName: "Piero Ciobanu",
        authorTag: "SENIOR · M",
        club: "UEA Boat Club",
        postedAgo: "3 min",
        caption: "Steady state + rate ladder",
        isPersonalBest: false,
        isWaterOuting: false,
        photoCaption: "ERG MONITOR PHOTO",
        headline: "16,000",
        headlineUnit: "m",
        stats: [("TIME", "1:04:50"), ("AVG /500M", "2:01.6"), ("RATE", "r19")],
        segments: [
            .init(tag: "WARMUP", distanceLabel: "2,000m"),
            .init(tag: "MAIN", distanceLabel: "12,000m"),
            .init(tag: "COOLDOWN", distanceLabel: "2,000m")
        ],
        reactions: .init(fire: 7, grimace: 3, clap: 2, commentCount: 4)
    )

    static let personalBest = MockFeedSession(
        authorName: "Alice Whitfield",
        authorTag: "SENIOR · W",
        club: "Durham University BC",
        postedAgo: "1h",
        caption: "",
        isPersonalBest: true,
        isWaterOuting: false,
        photoCaption: "ERG MONITOR PHOTO · 2K",
        headline: "7:04.1",
        headlineUnit: "2,000m",
        stats: [("AVG /500M", "1:46.0"), ("RATE", "r34"), ("−4.7s", "on PB")],
        segments: [.init(tag: "MAIN", distanceLabel: "2,000m")],
        reactions: .init(fire: 41, grimace: 6, clap: 19, commentCount: 23)
    )

    static let waterOuting = MockFeedSession(
        authorName: "Sam Okonkwo",
        authorTag: "NOVICE · M",
        club: "UEA Boat Club",
        postedAgo: "yesterday",
        caption: "Morning outing, flat water for once",
        isPersonalBest: false,
        isWaterOuting: true,
        photoCaption: "BOAT ON THE RIVER PHOTO",
        headline: "14.2",
        headlineUnit: "km on the water",
        stats: [("TIME", "1:12:00"), ("TYPE", "Outing")],
        segments: [],
        reactions: .init(fire: 0, grimace: 0, clap: 0, commentCount: 0)
    )
}

/// The feed card — header row, monitor photo with a glass data strip, segment
/// tags, and a reaction row. Anatomy matches the design brief's Screen 2.
struct SessionCardView: View {
    let session: MockFeedSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ZStack(alignment: .topLeading) {
                PhotoPlaceholder(cornerRadius: 0, caption: session.photoCaption)
                    .frame(height: session.isWaterOuting ? 240 : 300)

                if !session.isWaterOuting {
                    PhotoPlaceholder(cornerRadius: 16, caption: "SELFIE")
                        .frame(width: 84, height: 112)
                        .padding(12)
                }

                verificationBadge
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                VStack {
                    Spacer()
                    dataStrip
                        .padding(10)
                }
            }
            .frame(height: session.isWaterOuting ? 240 : 300)
            .clipped()

            if !session.caption.isEmpty {
                Text(session.caption)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, session.segments.isEmpty ? 14 : 6)
            }

            if !session.segments.isEmpty {
                HStack(spacing: 7) {
                    ForEach(session.segments, id: \.tag) { segment in
                        FilterChip(label: "\(segment.tag) \(segment.distanceLabel)", isSelected: segment.tag == "MAIN")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, session.caption.isEmpty ? 12 : 8)
                .padding(.bottom, 14)
            }

            if session.reactions.commentCount > 0 {
                reactionRow
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .background(Tokens.Ink.primary.opacity(session.isPersonalBest ? 0.02 : 0.02))
        .background(session.isPersonalBest ? Tokens.Accent.pb.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            if session.isPersonalBest {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Tokens.Accent.pb.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AvatarPlaceholder(diameter: 36)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    Text(session.authorName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(session.authorTag)
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
                Text(session.club)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Text(session.postedAgo)
                .textStyle(Typography.bodySecondary)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var verificationBadge: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if session.isPersonalBest {
                Text("PB")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Tokens.Base.dark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule().fill(Tokens.Accent.pb)
                    }
            }
            if !session.isWaterOuting {
                Label("Photo-verified", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Tokens.Accent.signal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule().fill(Tokens.Accent.signal.opacity(0.18))
                    }
            } else {
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

    private var dataStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            if session.isPersonalBest {
                Text("PERSONAL BEST · 2K TEST")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Tokens.Accent.pb)
            }
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(session.headline)
                    .font(.system(size: 34, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(session.isPersonalBest ? Tokens.Accent.pb : Tokens.Ink.primary)
                Text(session.headlineUnit)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            HStack(spacing: 22) {
                ForEach(session.stats, id: \.label) { stat in
                    StatColumn(label: stat.label, value: stat.value)
                }
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 22)
    }

    private var reactionRow: some View {
        HStack(spacing: 8) {
            reactionChip(emoji: "🔥", count: session.reactions.fire, highlighted: session.isPersonalBest)
            if session.reactions.clap > 0 {
                reactionChip(emoji: "👏", count: session.reactions.clap)
            }
            if session.reactions.grimace > 0 {
                reactionChip(emoji: "😬", count: session.reactions.grimace)
            }
            Spacer()
            Text("\(session.reactions.commentCount) comments")
                .textStyle(Typography.bodySecondary)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }

    private func reactionChip(emoji: String, count: Int, highlighted: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(emoji)
            Text("\(count)")
                .tabularNumerals()
                .fontWeight(highlighted ? .semibold : .regular)
                .foregroundStyle(highlighted ? Tokens.Accent.pb : Tokens.Ink.secondary)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background {
            Capsule().fill((highlighted ? Tokens.Accent.pb : Tokens.Ink.primary).opacity(highlighted ? 0.16 : 0.09))
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            SessionCardView(session: .steadyState)
            SessionCardView(session: .personalBest)
            SessionCardView(session: .waterOuting)
        }
        .padding()
    }
    .background(Tokens.Base.ground)
}
