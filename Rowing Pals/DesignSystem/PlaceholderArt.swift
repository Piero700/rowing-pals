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

    var body: some View {
        Circle()
            .fill(Tokens.Ink.primary.opacity(0.1))
            .overlay {
                Circle().strokeBorder(Tokens.Ink.primary.opacity(0.18), lineWidth: 1)
            }
            .frame(width: diameter, height: diameter)
            .overlay(alignment: .topTrailing) {
                if let streakDays, streakDays > 0 {
                    let badgeDiameter = max(14, diameter * 0.42)
                    Text("🔥")
                        .font(.system(size: badgeDiameter * 0.62))
                        .frame(width: badgeDiameter, height: badgeDiameter)
                        .background {
                            // Matches the prototype's own choice of --card
                            // (not the page background) as the badge's
                            // backdrop — a reasonable one-size-fits-most
                            // pick given this avatar renders over many
                            // different surfaces (feed cards, leaderboard
                            // rows, the profile header), not a value tuned
                            // per call site.
                            Circle().fill(Tokens.Surface.card)
                        }
                        .offset(x: badgeDiameter * 0.18, y: -badgeDiameter * 0.18)
                }
            }
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
