//
//  ProfilePostsGrid.swift
//  Rowing Pals
//

import SwiftUI

/// Profile's Posts tab: three photos to a row, each opening its post. On your own profile a
/// press-and-hold opens a small bubble: Make private / Make visible (decision 106), and Delete post
/// (decision 63), which Profile asks to confirm. A private post's tile wears a crossed-out eye.
struct ProfilePostsGrid: View {
    let viewModel: ProfileViewModel
    let onDelete: (UUID) -> Void
    @Environment(\.navigate) private var navigate

    /// The post whose Delete bubble a press-and-hold opened, and whether that press should stop the
    /// tap that follows it from opening the post.
    @State private var bubblePost: UUID?
    @State private var heldPost: UUID?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(viewModel.photos) { photo in
                ProfilePhotoTile(photo: photo, url: viewModel.photoURL(for: photo.monitorPath), isPrivate: photo.isPrivate)
                    .asButton {
                        // The release after a press-and-hold isn't a tap.
                        if heldPost == photo.id { heldPost = nil; return }
                        navigate(.post(photo.id))
                    }
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                        guard viewModel.isOwnProfile else { return }
                        heldPost = photo.id
                        bubblePost = photo.id
                    })
                    .sensoryFeedback(.impact, trigger: bubblePost) { _, new in new == photo.id }
                    .postActionsBubble(
                        isPresented: Binding(
                            get: { bubblePost == photo.id },
                            set: { if !$0 { bubblePost = nil } }
                        ),
                        isPrivate: photo.isPrivate,
                        onTogglePrivate: { Task { await viewModel.setPrivate(photo.id, !photo.isPrivate) } },
                        onDelete: { onDelete(photo.id) }
                    )
            }
        }
        .padding(.top, Tokens.Spacing.sectionTop)
        .alert("Couldn't change who can see the post", isPresented: Binding(
            get: { viewModel.privacyError != nil },
            set: { if !$0 { viewModel.privacyError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.privacyError ?? "")
        }
    }
}
