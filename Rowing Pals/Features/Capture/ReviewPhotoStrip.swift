//
//  ReviewPhotoStrip.swift
//  Rowing Pals
//

import SwiftUI

/// Environment photos on Review session — those with no monitor found — in a sideways strip.
struct ReviewPhotoStrip: View {
    let viewModel: ReviewSheetViewModel

    var body: some View {
        if !viewModel.galleryPhotos.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Tokens.Spacing.tight) {
                        ForEach(viewModel.galleryPhotos) { photo in
                            ReviewGalleryThumbnail(photo: photo, viewModel: viewModel)
                        }
                    }
                }
                Text("Press and hold a photo if it's actually a monitor photo.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.bottom, Tokens.Spacing.loose)
                    .guidance()
            }
        }
    }
}
