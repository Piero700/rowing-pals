//
//  ReviewGalleryThumbnail.swift
//  Rowing Pals
//

import SwiftUI

/// One environment photo on Review session: removable, or (press and hold) read as a monitor photo
/// if the guess was wrong.
struct ReviewGalleryThumbnail: View {
    let photo: ReviewSheetViewModel.GalleryPhoto
    let viewModel: ReviewSheetViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(data: photo.jpeg) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous))
                    .contextMenu {
                        Button {
                            viewModel.readGalleryPhotoAsMonitor(photo.id)
                        } label: {
                            Label("Read as monitor photo", icon: .scan)
                        }
                        Button(role: .destructive) {
                            viewModel.removeGalleryPhoto(photo.id)
                        } label: {
                            Label("Remove photo", icon: .trash)
                        }
                    }
            }
            Button {
                viewModel.removeGalleryPhoto(photo.id)
            } label: {
                RPIconView(icon: .close, size: Tokens.Icon.small)
                    .textStyle(Typography.navLabel)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    // 44-pt tap area around the small visible circle.
                    .frame(width: 44, height: 44, alignment: .topTrailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove photo")
        }
    }
}
