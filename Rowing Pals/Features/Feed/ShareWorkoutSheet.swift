//
//  ShareWorkoutSheet.swift
//  Rowing Pals
//

import SwiftUI

/// "Share workout" (v3 prototype's share sheet): a preview of the workout's image card, then
/// the iOS share sheet with that image. Opened from a feed card's share button.
struct ShareWorkoutSheet: View {
    let post: FeedPost
    /// Signed link to the lead piece's monitor photo; nil for a manual entry.
    let photoURL: URL?

    @State private var card: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sectionTop) {
            HStack {
                Text("Share workout")
                    .textStyle(Typography.navTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                GlassIconButton(systemImage: "xmark", accessibilityLabel: "Close") { dismiss() }
            }

            preview
                .frame(maxWidth: .infinity)

            if let card {
                ShareLink(
                    item: Image(uiImage: card),
                    preview: SharePreview("\(post.author.displayName)'s workout", image: Image(uiImage: card))
                ) {
                    Text("Share")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.rpPrimary)
            } else {
                Button {} label: {
                    Text("Share")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.rpPrimary)
                .disabled(true)
            }
        }
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.top, Tokens.Spacing.sectionTop)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Tokens.Base.ground)
        .task { await render() }
    }

    @ViewBuilder
    private var preview: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.photo, style: .continuous)
        if let card {
            Image(uiImage: card)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                .accessibilityLabel("Workout image: \(post.author.displayName), \(post.leadDistanceM.formattedMetres) in \(post.leadTimeMs.formattedDurationMs)")
        } else {
            shape.fill(Tokens.Surface.card)
                .aspectRatio(Tokens.Size.shareCardWidth / Tokens.Size.shareCardHeight, contentMode: .fit)
                .overlay { ProgressView().tint(Tokens.Ink.primary) }
                .accessibilityLabel("Preparing the workout image")
        }
    }

    /// Fetches the photo (from the feed's cache when it's there), then draws the card.
    @MainActor
    private func render() async {
        let photo = await loadPhoto()
        let content = ShareCardView(
            photo: photo,
            name: post.author.displayName,
            detail: "\(post.workoutLabel ?? "Training") · \(post.postedAt.formatted(date: .abbreviated, time: .omitted))",
            distance: post.leadDistanceM.formattedMetres,
            time: post.leadTimeMs.formattedDurationMs,
            split: post.leadSplitMs?.formattedPace(display: .split) ?? "—"
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        card = renderer.uiImage
    }

    /// Without the photo the card is still made, numbers on the plain ground.
    @MainActor
    private func loadPhoto() async -> UIImage? {
        guard let photoURL else { return nil }
        return await ImageCache.shared.load(photoURL)
    }
}
