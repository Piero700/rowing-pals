//
//  ShareCardView.swift
//  Rowing Pals
//

import SwiftUI

/// The image a shared workout becomes (user's choice, 2026-10-04): the lead piece's monitor
/// photo, full bleed, with the rower's name and that piece's distance, time and /500m over a
/// dark fade, plus the app's name. Always drawn in the dark palette — it's a picture, so it
/// looks the same wherever it's posted. Rendered at 3× by `ShareWorkoutSheet` (1080 × 1350 px).
struct ShareCardView: View {
    let photo: UIImage?
    let name: String
    /// "UT2 · 5 Oct 2026".
    let detail: String
    let distance: String
    let time: String
    let split: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Tokens.Base.ground
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Tokens.Size.shareCardWidth, height: Tokens.Size.shareCardHeight)
                    .clipped()
            }
            LinearGradient(
                colors: [Tokens.Base.ground.opacity(0), Tokens.Base.ground.opacity(0.94)],
                startPoint: UnitPoint(x: 0.5, y: 0.35),
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                Text(detail)
                    .textStyle(Typography.overline)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                Text(name)
                    .textStyle(Typography.profileName)
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(alignment: .top, spacing: Tokens.Spacing.tight) {
                    metric("Distance", distance)
                    metric("Time", time)
                    metric("/500m", split)
                }
                .padding(.top, 4)
            }
            .padding(Tokens.Spacing.sectionTop)
        }
        .overlay(alignment: .topLeading) {
            Text("Rowing Pals")
                .textStyle(Typography.overline)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.horizontal, Tokens.Spacing.gap)
                .padding(.vertical, 6)
                .background { Capsule().fill(Tokens.Base.ground.opacity(0.6)) }
                .padding(Tokens.Spacing.loose)
        }
        .frame(width: Tokens.Size.shareCardWidth, height: Tokens.Size.shareCardHeight)
        .environment(\.colorScheme, .dark)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .textStyle(Typography.metricLabel)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(value)
                .textStyle(Typography.selectedValue)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
