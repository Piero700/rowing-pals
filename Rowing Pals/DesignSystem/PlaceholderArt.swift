//
//  PlaceholderArt.swift
//  Rowing Pals
//

import SwiftUI

/// A diagonal-stripe fill standing in for a photo, avatar or crest until real
/// media exists. Every "photo" in the app is this until capture/storage land.
struct PhotoPlaceholder: View {
    var cornerRadius: CGFloat = 16
    var caption: String? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(stripes)
            .overlay(alignment: .bottom) {
                if let caption {
                    Text(caption)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.bottom, 8)
                }
            }
    }

    private var stripes: some ShapeStyle {
        Tokens.Ink.primary.opacity(0.08)
    }
}

/// A circular variant for avatars and crests. A stroked outline keeps it
/// readable against low-contrast row backgrounds, especially in light mode.
///
/// `streakDays` adds the redesign's 🔥 badge (docs/design/rowing-pals-redesign-handoff-v2.md
/// §3) whenever it's greater than zero — appears wherever an avatar does
/// (feed, rankings, profile), not profile-only, so it lives here rather
/// than being bolted on at each call site. Pass `nil` (the default) where
/// a streak genuinely isn't known yet rather than fetching it separately
/// just to satisfy this parameter — batch it into whatever query already
/// loads the surrounding row's data instead (see FeedViewModel/
/// MetresLeaderboardViewModel/TestLeaderboardViewModel for the pattern:
/// one batched `daily_totals` fetch computes every visible row's streak
/// client-side, not one `current_streak(...)` RPC call per avatar).
struct AvatarPlaceholder: View {
    var diameter: CGFloat = 36
    var streakDays: Int? = nil
    /// When given, the avatar shows the rower's initials, as in v3.
    var name: String? = nil
    /// When given, the avatar shows the rower's profile picture once it loads (decision 29),
    /// over the initials; with no picture, or one this viewer may not see, the initials stay.
    var userId: UUID? = nil

    /// v3 avatar: a circle with a 145° gradient from `recordsSoft` to `raised`, initials in the
    /// records colour at heavy weight, and a 🔥 streak badge in a card-coloured circle at the
    /// top-right (23 pt at the 41 pt feed size, scaled for other sizes).
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Tokens.Accent.recordsSoft, Tokens.Surface.raised],
                    startPoint: UnitPoint(x: 0.15, y: 0.1),
                    endPoint: UnitPoint(x: 0.85, y: 0.9)
                )
            )
            .overlay {
                if let initials {
                    Text(initials)
                        .font(.system(size: diameter * 0.36, weight: .heavy))
                        .foregroundStyle(Tokens.Accent.records)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .overlay {
                if let url = userId.flatMap({ AvatarStore.shared.url(for: $0) }) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil, let userId {
                            Color.clear.onAppear { AvatarStore.shared.linkFailed(userId) }
                        }
                    }
                    .clipShape(Circle())
                }
            }
            .frame(width: diameter, height: diameter)
            .task(id: userId) {
                if let userId { AvatarStore.shared.load(userId) }
            }
            .overlay(alignment: .topTrailing) {
                if let streakDays, streakDays > 0 {
                    let badgeDiameter = diameter * 23 / 41
                    Text("🔥")
                        .font(.system(size: badgeDiameter * 0.65))
                        .frame(width: badgeDiameter, height: badgeDiameter)
                        .background { Circle().fill(Tokens.Surface.card) }
                        .offset(x: diameter * 5 / 41, y: -diameter * 5 / 41)
                        .accessibilityLabel("\(streakDays)-day streak")
                }
            }
            .accessibilityElement(children: .combine)
    }

    /// First letters of the first two words: "Piero Ciobanu" → "PC", "Joe" → "J".
    private var initials: String? {
        guard let name else { return nil }
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? nil : String(letters).uppercased()
    }
}

#Preview {
    VStack(spacing: 20) {
        PhotoPlaceholder(caption: "ERG MONITOR PHOTO")
            .frame(height: 160)
        AvatarPlaceholder(diameter: 52)
    }
    .padding()
    .background(Tokens.Base.ground)
}
