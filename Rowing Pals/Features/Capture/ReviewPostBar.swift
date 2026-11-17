//
//  ReviewPostBar.swift
//  Rowing Pals
//

import SwiftUI

/// Review session's sticky "Post session" bar, with the reason posting is unavailable or the error
/// from the last try above it.
struct ReviewPostBar: View {
    let viewModel: ReviewSheetViewModel
    let onPosted: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            if let postError = viewModel.postError {
                Text(postError)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.System.error)
            } else if let blocker = viewModel.postBlocker {
                Text(blocker)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Button {
                Task {
                    if await viewModel.post() {
                        NotificationCenter.default.post(name: .sessionPosted, object: nil)
                        onPosted()
                    }
                }
            } label: {
                if viewModel.isPosting {
                    ProgressView().tint(Tokens.Ink.onBrand)
                } else {
                    Text("Post session")
                }
            }
            .buttonStyle(.rpPrimary)
            .disabled(!viewModel.canPost)
        }
        .padding(.horizontal, Tokens.Spacing.screen)
        .padding(.top, Tokens.Spacing.gap)
        .padding(.bottom, Tokens.Spacing.tight)
        .background(Tokens.Base.ground.ignoresSafeArea())
    }
}
